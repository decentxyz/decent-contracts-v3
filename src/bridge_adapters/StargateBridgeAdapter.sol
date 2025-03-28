// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUTB} from "../interfaces/IUTB.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {SwapInstructions, SwapParams} from "../CommonTypes.sol";
import {IStargateRouter, LzBridgeData} from "./stargate/IStargateRouter.sol";
import {IStargateReceiver} from "./stargate/IStargateReceiver.sol";
import {IStargateFactory} from "./stargate/IStargateFactory.sol";
import {IStargatePool} from "./stargate/IStargatePool.sol";
import {BaseAdapter} from "./BaseAdapter.sol";

// pool ids: https://stargateprotocol.gitbook.io/stargate/developers/pool-ids
// chain ids: https://stargateprotocol.gitbook.io/stargate/developers/chain-ids

contract StargateBridgeAdapter is
    BaseAdapter,
    IBridgeAdapter,
    IStargateReceiver
{
    uint8 public constant ID = 1;
    uint128 public gasForRelay = 100_000;
    mapping(uint256 chainId => address remoteBridgeAdapter) public destinationBridgeAdapter;
    mapping(uint256 chainId => uint16 lzId) public lzIdLookup;
    mapping(uint16 lzId => uint256 chainId) public chainIdLookup;

    IStargateRouter public stargateComposer;
    IStargateFactory public stargateFactory;
    address stargateEth;

    event InsufficientFunds();
    event InvalidToken();
    event ExecutionFailure();

    error NotEnoughGasForRelay();

    constructor(uint8 _decimals, address _stargateFactory) BaseAdapter() {
        decimals = _decimals;
        stargateFactory = IStargateFactory(_stargateFactory);
    }

    function setStargateComposer(address _stargateComposer) public onlyAdmin {
        stargateComposer = IStargateRouter(_stargateComposer);
    }

    function setStargateEth(address _stargateEth) public onlyAdmin {
        stargateEth = _stargateEth;
    }

    function setGasForRelay(uint128 _gasForRelay) external onlyAdmin {
        emit SetGasForRelay(gasForRelay, _gasForRelay);
        gasForRelay = _gasForRelay;
    }

    function registerRemoteBridgeAdapter(
        uint256 dstChainId,
        uint16 dstLzId,
        uint8 dstDecimals,
        address dstBridgeAdapter
    ) public onlyAdmin onlyValidLzAdapter(
        dstChainId,
        uint32(dstLzId),
        dstDecimals,
        dstBridgeAdapter
    ) {
        lzIdLookup[dstChainId] = dstLzId;
        chainIdLookup[dstLzId] = dstChainId;
        destinationBridgeAdapter[dstChainId] = dstBridgeAdapter;
        remoteDecimals[dstChainId] = dstDecimals;
        emit RegisteredRemoteBridgeAdapter(dstChainId, dstLzId, dstDecimals, dstBridgeAdapter);
    }

    function getBridgeToken(
        bytes calldata additionalArgs
    ) external pure returns (address bridgeToken) {
        bridgeToken = abi.decode(additionalArgs, (address));
    }

    function _removeDust(
        uint256 amount,
        bytes calldata additionalArgs
    ) private returns (uint256 amt2Bridge, uint256 dust) {
        address stargatePool = stargateFactory.getPool(_getSrcPoolId(additionalArgs));
        uint256 rate = IStargatePool(stargatePool).convertRate();
        amt2Bridge = rate != 1 ? (amount / rate) * rate : amount;
        dust = amount - amt2Bridge;
    }

    function bridge(
        BridgeCall calldata bridgeCall
    ) public payable onlyUtb remotePrecision(bridgeCall.dstChainId, bridgeCall.postBridge.swapParams) {
        address bridgeToken = abi.decode(bridgeCall.additionalArgs, (address));

        bytes memory bridgePayload = abi.encode(
            bridgeCall.postBridge,
            bridgeCall.target,
            bridgeCall.paymentOperator,
            bridgeCall.payload,
            bridgeCall.refund,
            bridgeCall.txId
        );

        if ( bridgeToken != address(0) ) {
            SafeERC20.safeTransferFrom(
                IERC20(bridgeToken),
                msg.sender,
                address(this),
                bridgeCall.amount
            );
            SafeERC20.forceApprove(IERC20(bridgeToken), address(stargateComposer), bridgeCall.amount);
        }

        (uint256 amt2Bridge, uint256 dust) = _removeDust(bridgeCall.amount, bridgeCall.additionalArgs);

        _callBridge(
            amt2Bridge,
            bridgeCall.dstChainId,
            bridgePayload,
            bridgeCall.additionalArgs,
            bridgeCall.refund
        );

        if ( dust > 0 ) {
            _refundUser(bridgeCall.refund, bridgeToken, dust);
        }
    }

    function _getValue(
        bytes calldata additionalArgs,
        uint256 amt2Bridge
    ) private pure returns (uint value) {
        (address bridgeToken, LzBridgeData memory lzBridgeData) = abi.decode(
            additionalArgs,
            (address, LzBridgeData)
        );
        return bridgeToken == address(0)
            ? (lzBridgeData.fee + amt2Bridge)
            : lzBridgeData.fee;
    }

    function _getLzTxObj(
        bytes calldata additionalArgs
    ) private view returns (IStargateRouter.lzTxObj memory) {
        (, , IStargateRouter.lzTxObj memory lzTxObj) = abi.decode(
            additionalArgs,
            (address, LzBridgeData, IStargateRouter.lzTxObj)
        );

        if ( lzTxObj.dstGasForCall < gasForRelay ) {
            revert NotEnoughGasForRelay();
        }

        return lzTxObj;
    }

    function _getSlippage(
        bytes calldata additionalArgs
    ) private pure returns (uint16) {
        (, , , uint16 slippage) = abi.decode(
            additionalArgs,
            (address, LzBridgeData, IStargateRouter.lzTxObj, uint16)
        );
        return slippage;
    }

    function _getDstChainId(
        bytes calldata additionalArgs
    ) private pure returns (uint16) {
        (, LzBridgeData memory lzBridgeData, ) = abi.decode(
            additionalArgs,
            (address, LzBridgeData, IStargateRouter.lzTxObj)
        );
        return lzBridgeData._dstChainId;
    }

    function _getSrcPoolId(
        bytes calldata additionalArgs
    ) private pure returns (uint120) {
        (, LzBridgeData memory lzBridgeData, ) = abi.decode(
            additionalArgs,
            (address, LzBridgeData, IStargateRouter.lzTxObj)
        );
        return lzBridgeData._srcPoolId;
    }

    function _getDstPoolId(
        bytes calldata additionalArgs
    ) private pure returns (uint120) {
        (, LzBridgeData memory lzBridgeData, ) = abi.decode(
            additionalArgs,
            (address, LzBridgeData, IStargateRouter.lzTxObj)
        );
        return lzBridgeData._dstPoolId;
    }

    function _getDestAdapter(uint chainId) private view returns (address dstAddr) {
        dstAddr = destinationBridgeAdapter[chainId];

        if (dstAddr == address(0)) revert NoDstBridge();
    }

    function _callBridge(
        uint256 amt2Bridge,
        uint256 dstChainId,
        bytes memory bridgePayload,
        bytes calldata additionalArgs,
        address refund
    ) private {
        stargateComposer.swap{value: _getValue(additionalArgs, amt2Bridge)}(
            _getDstChainId(additionalArgs), //lzBridgeData._dstChainId, // send to LayerZero chainId
            _getSrcPoolId(additionalArgs), //lzBridgeData._srcPoolId, // source pool id
            _getDstPoolId(additionalArgs), //lzBridgeData._dstPoolId, // dst pool id
            payable(refund), // refund adddress. extra gas (if any) is returned to this address
            amt2Bridge, // quantity to swap
            (amt2Bridge * (100_00 - _getSlippage(additionalArgs))) / 100_00, // the min qty you would accept on the destination, fee is 6 bips
            _getLzTxObj(additionalArgs), // additional gasLimit increase, airdrop, at address
            abi.encodePacked(_getDestAdapter(dstChainId)),
            bridgePayload // bytes param, if you wish to send additional payload you can abi.encode() them here
        );
    }

    function sgReceive(
        uint16, // _srcChainid
        bytes memory, // _srcAddress
        uint256, // _nonce
        address tokenIn, // _token
        uint256 amountLD, // amountLD
        bytes memory payload
    ) external override onlyExecutor {
        (
            SwapInstructions memory postBridge,
            address target,
            address paymentOperator,
            bytes memory utbPayload,
            address payable refund,
            bytes32 txId
        ) = abi.decode(
                payload,
                (SwapInstructions, address, address, bytes, address, bytes32)
            );

        if (
            postBridge.swapParams.tokenIn != tokenIn
                && !(postBridge.swapParams.tokenIn == address(0) && tokenIn == stargateEth)
        ) {
            _refundUser(refund, tokenIn, amountLD);
            emit InvalidToken();
            return;
        }

        if ( amountLD != postBridge.swapParams.amountIn ) {
            postBridge.swapParams.amountIn = amountLD;
        }

        uint256 bridgeValue;
        if ( postBridge.swapParams.tokenIn == address(0) ) {
            bridgeValue = postBridge.swapParams.amountIn;
        } else {
            SafeERC20.forceApprove(
                IERC20(postBridge.swapParams.tokenIn),
                utb,
                postBridge.swapParams.amountIn
            );
        }

        try IUTB(utb).receiveFromBridge{value: bridgeValue}(
            postBridge,
            target,
            paymentOperator,
            utbPayload,
            refund,
            ID,
            txId
        ) {
            if ( amountLD > postBridge.swapParams.amountIn ) {
                _refundUser(refund, tokenIn, amountLD - postBridge.swapParams.amountIn);
            }
        } catch (bytes memory) {
            _refundUser(refund, tokenIn, amountLD);
            emit ExecutionFailure();
        }

        if ( postBridge.swapParams.tokenIn != address(0) ) {
            SafeERC20.safeApprove(IERC20(postBridge.swapParams.tokenIn), utb, 0);
        }
    }

    function _refundUser(address user, address token, uint amount) private {
        if ( token == address(0) || token == stargateEth ) {
            (bool success, ) = user.call{value: amount}("");
            require(success);
        } else {
            SafeERC20.safeTransfer(IERC20(token), user, amount);
        }
    }
}
