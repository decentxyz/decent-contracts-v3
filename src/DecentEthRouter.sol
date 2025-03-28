// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IWETH} from "./interfaces/IWETH.sol";
import {IDcntEth, IDecimalConversionRate} from "./interfaces/IDcntEth.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {Roles} from "./utils/Roles.sol";
import {Withdrawable} from "./utils/Withdrawable.sol";
import {IDecentBridgeExecutor} from "./interfaces/IDecentBridgeExecutor.sol";
import {IDecentEthRouter} from "./interfaces/IDecentEthRouter.sol";

contract DecentEthRouter is IDecentEthRouter, ILayerZeroComposer, Roles, Withdrawable {
    IWETH public weth;
    IDcntEth public dcntEth;
    IDecentBridgeExecutor public executor;

    uint8 public constant MT_ETH_TRANSFER = 0;
    uint8 public constant MT_ETH_TRANSFER_WITH_PAYLOAD = 1;

    uint128 public gasForRelay = 120_000;

    bool public gasCurrencyIsEth; // for chains that use ETH as gas currency

    bytes32 public constant BRIDGE_OPERATOR_ROLE = keccak256("BRIDGE_OPERATOR_ROLE");
    bool public requireOperator;

    mapping(uint32 lzId => address dstRouter) public destinationBridges;

    using OptionsBuilder for bytes;

    constructor(
        address payable _weth,
        bool gasIsEth,
        address _executor
    ) Roles(msg.sender) {
        weth = IWETH(_weth);
        gasCurrencyIsEth = gasIsEth;
        executor = IDecentBridgeExecutor(payable(_executor));
    }

    modifier onlyEthChain() {
        if (!gasCurrencyIsEth) revert OnlyEthChain();
        _;
    }

    modifier onlyLzEndpoint() {
        if (address(dcntEth.endpoint()) != msg.sender) revert OnlyLzEndpoint();
        _;
    }

    modifier onlyDcntEth(address from) {
        if (from != address(dcntEth)) revert OnlyDcntEth();
        _;
    }

    modifier onlyOperator() {
        if (requireOperator && !hasRole(BRIDGE_OPERATOR_ROLE, msg.sender)) revert OnlyBridgeOperator();
        _;
    }

    modifier onlyIfWeHaveEnoughReserves(uint256 amount) {
        if (weth.balanceOf(address(this)) < amount) revert NotEnoughReserves();
        _;
    }

    modifier onlyWeth() {
        if (msg.sender != address(weth)) revert OnlyWeth();
        _;
    }

    function setWeth(address payable _weth) public onlyAdmin {
        weth = IWETH(_weth);
        emit SetWeth(_weth);
    }

    function setExecutor(address _executor) public onlyAdmin {
        executor = IDecentBridgeExecutor(payable(_executor));
        emit SetExecutor(_executor);
    }

    function setGasForRelay(uint128 _gasForRelay) external onlyAdmin {
        emit SetGasForRelay(gasForRelay, _gasForRelay);
        gasForRelay = _gasForRelay;
    }

    /// @inheritdoc IDecentEthRouter
    function registerDcntEth(address _addr) public onlyAdmin {
        dcntEth = IDcntEth(_addr);
        emit RegisteredDcntEth(_addr);
    }

    /// @inheritdoc IDecentEthRouter
    function addDestinationBridge(
        uint32 _dstChainId,
        address _routerAddress
    ) public onlyAdmin {
        destinationBridges[_dstChainId] = _routerAddress;
        emit AddedDestinationBridge(_dstChainId, _routerAddress);
    }

    function _refundDust(address to, uint256 dust) private {
        if ( dust > 0 ) {
            if (gasCurrencyIsEth) {
                (bool success, ) = to.call{value: dust}("");
                if (!success) {
                    revert TransferFailed();
                }
            } else {
                weth.transfer(to, dust);
            }
        }
    }

    function _getCallParams(
        DecentBridgeCall memory bridgeCall
    ) private view returns (SendParam memory sendParam) {
        bytes32 dstRouter = bytes32(abi.encode(destinationBridges[bridgeCall.dstChainId]));

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(gasForRelay, 0)
            .addExecutorLzComposeOption(0, bridgeCall.dstGasForCall, 0);

        bytes memory payload;

        if (bridgeCall.msgType == MT_ETH_TRANSFER) {
            payload = abi.encode(
                bridgeCall.msgType,
                bridgeCall.toAddress,
                bridgeCall.refundAddress,
                bridgeCall.deliverEth
            );
        } else {
            payload = abi.encode(
                bridgeCall.msgType,
                bridgeCall.toAddress,
                bridgeCall.refundAddress,
                bridgeCall.deliverEth,
                bridgeCall.payload
            );
        }

        uint256 rate = IDecimalConversionRate(address(dcntEth)).decimalConversionRate();
        uint256 amount = (bridgeCall.amount / rate) * rate;

        sendParam = SendParam({
            dstEid: bridgeCall.dstChainId,
            to: dstRouter,
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: options,
            composeMsg: payload,
            oftCmd: ""
        });
    }

    function estimateSendAndCallFee(
        uint8 msgType,
        uint32 dstChainId,
        address toAddress,
        address refundAddress,
        uint256 amount,
        uint64 dstGasForCall,
        bool deliverEth,
        bytes memory payload
    ) public view returns (uint nativeFee, uint zroFee) {
        SendParam memory sendParam = _getCallParams(
            DecentBridgeCall({
                msgType: msgType,
                dstChainId: dstChainId,
                toAddress: toAddress,
                refundAddress: refundAddress,
                amount: amount,
                dstGasForCall: dstGasForCall,
                deliverEth: deliverEth,
                payload: payload
            })
        );

        MessagingFee memory messagingFee = dcntEth.quoteSend(sendParam, false);

        nativeFee = messagingFee.nativeFee;
        zroFee = messagingFee.lzTokenFee;
    }

    function _bridgeWithPayload(DecentBridgeCall memory bridgeCall) internal {
        SendParam memory sendParam = _getCallParams(bridgeCall);

        MessagingFee memory messagingFee = dcntEth.quoteSend(sendParam, false);

        uint256 dust = bridgeCall.amount - sendParam.amountLD;
        uint gasValue;

        if (gasCurrencyIsEth) {
            weth.deposit{value: sendParam.amountLD}();
            gasValue = msg.value - dust - sendParam.amountLD;
        } else {
            weth.transferFrom(msg.sender, address(this), bridgeCall.amount);
            gasValue = msg.value;
        }

        dcntEth.mint(address(this), sendParam.amountLD);

        dcntEth.send{value: gasValue}(
            sendParam,
            messagingFee,
            bridgeCall.refundAddress
        );

        _refundDust(bridgeCall.refundAddress, dust);

        emit BridgedPayload();
    }

    /// @inheritdoc IDecentEthRouter
    function bridgeWithPayload(
        uint32 dstChainId,
        address toAddress,
        address refundAddress,
        uint amount,
        bool deliverEth,
        uint64 dstGasForCall,
        bytes memory payload
    ) public payable onlyOperator {
        return _bridgeWithPayload(
            DecentBridgeCall({
                msgType: MT_ETH_TRANSFER_WITH_PAYLOAD,
                dstChainId: dstChainId,
                toAddress: toAddress,
                refundAddress: refundAddress,
                amount: amount,
                dstGasForCall: dstGasForCall,
                deliverEth: deliverEth,
                payload: payload
            })
        );
    }

    /// @inheritdoc IDecentEthRouter
    function bridge(
        uint32 dstChainId,
        address toAddress,
        address refundAddress,
        uint amount,
        uint64 dstGasForCall,
        bool deliverEth
    ) public payable onlyOperator {
        _bridgeWithPayload(
            DecentBridgeCall({
                msgType: MT_ETH_TRANSFER,
                dstChainId: dstChainId,
                toAddress: toAddress,
                refundAddress: refundAddress,
                amount: amount,
                dstGasForCall: dstGasForCall,
                deliverEth: deliverEth,
                payload: ""
            })
        );
    }

    function lzCompose(
        address _from,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) external payable onlyLzEndpoint onlyDcntEth(_from) {
        bytes memory composeMsg = OFTComposeMsgCodec.composeMsg(_message);
        uint256 amount = OFTComposeMsgCodec.amountLD(_message);

        (
            uint8 msgType,
            address to,
            address refundAddress,
            bool deliverEth
        ) = abi.decode(composeMsg, (uint8, address, address, bool));

        bytes memory payload = "";

        if (msgType == MT_ETH_TRANSFER_WITH_PAYLOAD) {
            (, , , , payload) = abi.decode(
                composeMsg,
                (uint8, address, address, bool, bytes)
            );
        }

        if (weth.balanceOf(address(this)) < amount) {
            dcntEth.transfer(refundAddress, amount);
            return;
        }

        dcntEth.burn(address(this), amount);

        if (msgType == MT_ETH_TRANSFER) {
            if (!gasCurrencyIsEth || !deliverEth) {
                weth.transfer(to, amount);
            } else {
                weth.withdraw(amount);
                (bool success, ) = payable(to).call{value: amount}("");
                if (!success) {
                    weth.deposit{value: amount}();
                    weth.transfer(refundAddress, amount);
                }
            }
        } else {
            weth.approve(address(executor), amount);
            try executor.execute(refundAddress, to, deliverEth, amount, payload) {
                return;
            } catch (bytes memory) {
                weth.transfer(refundAddress, amount);
                weth.approve(address(executor), 0);
            }
        }

        emit ReceivedPayload();
    }

    /// @inheritdoc IDecentEthRouter
    function redeemEth() public {
        _removeLiquidityEth(msg.sender, dcntEth.balanceOf(msg.sender));
    }

    /// @inheritdoc IDecentEthRouter
    function redeemWeth() public {
        _removeLiquidityWeth(msg.sender, dcntEth.balanceOf(msg.sender));
    }

    /// @inheritdoc IDecentEthRouter
    function redeemEthFor(address account, uint256 amount) public onlyAdmin {
        _removeLiquidityEth(account, amount);
    }

    /// @inheritdoc IDecentEthRouter
    function redeemWethFor(address account, uint256 amount) public onlyAdmin {
        _removeLiquidityWeth(account, amount);
    }

    /// @inheritdoc IDecentEthRouter
    function addLiquidityEth()
        public
        payable
        onlyEthChain
    {
        weth.deposit{value: msg.value}();
        dcntEth.mint(msg.sender, msg.value);
        emit AddedLiquidity(msg.value);
    }

    /// @inheritdoc IDecentEthRouter
    function removeLiquidityEth(
        uint256 amount
    ) public onlyEthChain {
        _removeLiquidityEth(msg.sender, amount);
    }

    /**
     * @dev Internal function to withdraw a users bridge liquidity for ETH
     * @param account The address to burn dcntEth from and send ETH to
     * @param amount The amount of ETH to withdraw
     */
    function _removeLiquidityEth(address account, uint256 amount) onlyIfWeHaveEnoughReserves(amount) private {
        dcntEth.burn(account, amount);
        weth.withdraw(amount);
        (bool success, ) = payable(account).call{value: amount}("");
        if (!success) {
            revert TransferFailed();
        }
        emit RemovedLiquidity(amount);
    }

    /// @inheritdoc IDecentEthRouter
    function addLiquidityWeth(
        uint256 amount
    ) public {
        weth.transferFrom(msg.sender, address(this), amount);
        dcntEth.mint(msg.sender, amount);
        emit AddedLiquidity(amount);
    }

    /// @inheritdoc IDecentEthRouter
    function removeLiquidityWeth(
        uint256 amount
    ) public {
        _removeLiquidityWeth(msg.sender, amount);
    }

    /**
     * @dev Internal function to withdraw a users bridge liquidity for WETH
     * @param account The address to burn dcntEth from and send WETH to
     * @param amount The amount of WETH to withdraw
     */
    function _removeLiquidityWeth(address account, uint256 amount) private onlyIfWeHaveEnoughReserves(amount) {
        dcntEth.burn(account, amount);
        weth.transfer(account, amount);
        emit RemovedLiquidity(amount);
    }

    function setRequireOperator(
        bool _requireOperator
    ) public onlyAdmin {
        requireOperator = _requireOperator;
        emit SetRequireOperator(_requireOperator);
    }

    receive() external payable onlyWeth {}
}
