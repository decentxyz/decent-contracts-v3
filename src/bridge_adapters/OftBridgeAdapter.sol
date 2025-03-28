// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUTB} from "../interfaces/IUTB.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {SwapInstructions, SwapParams} from "../CommonTypes.sol";
import {BaseAdapter} from "./BaseAdapter.sol";
import {IOFT, MessagingFee, SendParam, OFTReceipt, OFTLimit, OFTFeeDetail} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {IDecimalConversionRate} from "../interfaces/IDcntEth.sol";
import {IOAppCore} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppCore.sol";

contract OftBridgeAdapter is IBridgeAdapter, BaseAdapter {
    using OptionsBuilder for bytes;

    struct OftConfig {
        bool permissioned;
        address bridgeToken;
    }

    uint8 public constant ID = 5;
    mapping(uint256 chainId => address remoteBridgeAdapter) public destinationBridgeAdapter;
    mapping(uint256 chainId => uint32 lzId) public lzIdLookup;
    mapping(uint32 lzId => uint256 chainId) public chainIdLookup;
    mapping(address oft => OftConfig) public oftLookup;

    uint128 public gasForRelay = 120_000;

    event OftPermissioned(address token, address oft);
    event OftDisallowed(address oft);
    event RefundIssued(address recipient, address token, uint256 amount);
    event ReceivedOft(address token, uint256 amount);
    event SentOft(address token, uint256 amount);

    error OnlyPermissionedOft();
    error OnlyLzEndpoint();
    error InvalidBridgeToken();
    error RefundFailed();

    constructor(uint8 _decimals) BaseAdapter() {
        decimals = _decimals;
    }

    /**
     * @dev Registers a remote bridge adapter for a specified destination chain.
     * @param dstChainId The chain ID of the destination chain.
     * @param dstLzId The LayerZero endpoint ID for the destination chain.
     * @param dstDecimals The number of decimals on the destination chain.
     * @param dstBridgeAdapter The address of the bridge adapter to register.
     */
    function registerRemoteBridgeAdapter(
        uint256 dstChainId,
        uint32 dstLzId,
        uint8 dstDecimals,
        address dstBridgeAdapter
    ) public onlyAdmin onlyValidLzAdapter(
        dstChainId,
        dstLzId,
        dstDecimals,
        dstBridgeAdapter
    ) {
        lzIdLookup[dstChainId] = dstLzId;
        chainIdLookup[dstLzId] = dstChainId;
        destinationBridgeAdapter[dstChainId] = dstBridgeAdapter;
        remoteDecimals[dstChainId] = dstDecimals;
        emit RegisteredRemoteBridgeAdapter(dstChainId, dstLzId, dstDecimals, dstBridgeAdapter);
    }

    /**
     * @dev Sets the minimum amount of gas for relaying destination transactions.
     * @param _gasForRelay The minimum amount of gas for relaying.
     */
    function setGasForRelay(uint128 _gasForRelay) external onlyAdmin {
        emit SetGasForRelay(gasForRelay, _gasForRelay);
        gasForRelay = _gasForRelay;
    }

    /**
     * @dev Gets the address of the bridge token encoded in the additional args.
     * @param additionalArgs Encoded additional args for the oft bridge adapter.
     */
    function getBridgeToken(bytes calldata additionalArgs) public pure returns (address token) {
        token = abi.decode(additionalArgs, (address));
    }

    /**
     * @dev Gets the address of the OFT (oft or adapter) encoded in the additional args.
     * @param additionalArgs Encoded additional args for the oft bridge adapter.
     */
    function getOft(bytes calldata additionalArgs) public pure returns (address oft) {
        (,,oft) = abi.decode(additionalArgs, (address, uint64, address));
    }

    /**
     * @dev Gets the additional destination gas for relaying the tx on the destination chain.
     * @param additionalArgs Encoded additional args for the oft bridge adapter.
     */
    function _getDstGas(bytes calldata additionalArgs) internal pure returns (uint64 gas) {
        (,gas) = abi.decode(additionalArgs, (address, uint64));
    }

    /**
     * @dev Permits an OFT to interact with this bridge adapter.
     * @param _bridgeToken The address of the underlying token being permissioned.
     * @param _oft The address of the OFT (oft or adapter) responsible for transferring the underlying.
     */
    function permissionOft(address _bridgeToken, address _oft) external onlyAdmin {
        if (IOFT(_oft).token() != _bridgeToken) revert InvalidBridgeToken();
        oftLookup[_oft] = OftConfig({
            permissioned: true,
            bridgeToken: _bridgeToken
        });
        emit OftPermissioned(_bridgeToken, _oft);
    }

    /**
     * @dev Disallows an OFT from interacting with this bridge adapter.
     * @param _oft The address of the OFT (oft or adapter) being disallowed.
     */
    function disallowOft(address _oft) external onlyAdmin {
        oftLookup[_oft].permissioned = false;
        emit OftDisallowed(_oft);
    }

    /**
     * @dev Bridges the OFT's underlying token to the bridge adapter on the destination chain.
     * @param bridgeCall Specifies the amount, destination chain, and post-bridge instructions.
     */
    function bridge(BridgeCall calldata bridgeCall) public payable onlyUtb
        remotePrecision(bridgeCall.dstChainId, bridgeCall.postBridge.swapParams)
    {
        if (destinationBridgeAdapter[bridgeCall.dstChainId] == address(0)) revert NoDstBridge();

        address bridgeToken = getBridgeToken(bridgeCall.additionalArgs);
        address oft = getOft(bridgeCall.additionalArgs);

        SendParam memory sendParam = _getSendParam(bridgeCall, bridgeToken, oft);

        if ( bridgeToken != address(0) ) {
            SafeERC20.safeTransferFrom(IERC20(bridgeToken), msg.sender, address(this), bridgeCall.amount);
        }

        uint256 sentNative = _sendOft(
            bridgeToken,
            oft,
            sendParam,
            bridgeCall.refund
        );

        emit SentOft(bridgeToken, sendParam.amountLD);

        _refundUser(bridgeCall.refund, address(0), msg.value - sentNative);

        if ( bridgeToken != address(0) ) {
            uint256 dust = bridgeCall.amount - sendParam.amountLD;
            _refundUser(bridgeCall.refund, bridgeToken, dust);
        }
    }

    /**
     * @dev Calls the OFT to bridge the underlying token to the destination OFT.
     * @param bridgeToken The address of the underlying token being bridged.
     * @param oft The address of the OFT responsible for transferring the underlying.
     * @param sendParam Struct containing the parameters for the OFT transfer.
     * @param refund The address to refund excess funds to on the source chain.
     */
    function _sendOft(
        address bridgeToken,
        address oft,
        SendParam memory sendParam,
        address refund
    ) internal returns (uint256 value) {
        // approve the oft sender if it isn't the bridge token, and the oft is an erc20
        if (bridgeToken != address(0)) {
            if (IOFT(oft).approvalRequired() && IERC20(bridgeToken).allowance(address(this), oft) < sendParam.amountLD) {
                SafeERC20.forceApprove(IERC20(bridgeToken), oft, sendParam.amountLD);
            }
        }

        // get messagingFee
        MessagingFee memory messagingFee = IOFT(oft).quoteSend(sendParam, false);

        value = bridgeToken == address(0)
            ? messagingFee.nativeFee + sendParam.amountLD
            : messagingFee.nativeFee;

        // bridge send OFT to dst OftRouter
        IOFT(oft).send{value: value}(sendParam, messagingFee, refund);
    }

    /**
     * @dev Estimates the fees required to bridge the OFT's underlying token to the destination chain.
     * @param bridgeCall Specifies the amount, destination chain, and post-bridge instructions.
     */
    function estimateFees(BridgeCall calldata bridgeCall) public view returns (uint256, uint256){
        address bridgeToken = getBridgeToken(bridgeCall.additionalArgs);
        address oft = getOft(bridgeCall.additionalArgs);

        SendParam memory sendParam = _getSendParam(bridgeCall, bridgeToken, oft);
        MessagingFee memory messagingFee = IOFT(oft).quoteSend(sendParam, false);
        return (messagingFee.nativeFee, messagingFee.lzTokenFee);
    }

    /**
     * @dev Estimates the fees required to bridge the OFT's underlying token to the destination chain.
     * @param bridgeCall Specifies the amount, destination chain, and post-bridge instructions.
     */
    function estimateOft(BridgeCall calldata bridgeCall) public view returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        address bridgeToken = getBridgeToken(bridgeCall.additionalArgs);
        address oft = getOft(bridgeCall.additionalArgs);

        SendParam memory sendParam = _getSendParam(bridgeCall, bridgeToken, oft);
        return _quoteOFT(oft, sendParam);
    }

    /**
     * @dev Quotes the amount sent and received by the OFT, accounting for dust removal and fees.
     * @dev Utilizes the quoteOFT function if available, otherwise falls back to decimal conversion.
     * @param oft The address of the OFT (oft or adapter) responsible for transferring the underlying.
     * @param sendParam Struct containing the parameters for the OFT transfer.
     */
    function _quoteOFT(address oft, SendParam memory sendParam) private view returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        try IOFT(oft).quoteOFT(sendParam) returns (
            OFTLimit memory /* oftLimit */,
            OFTFeeDetail[] memory /* oftFeeDetails */,
            OFTReceipt memory oftReceipt
        ) {
            return (oftReceipt.amountSentLD, oftReceipt.amountReceivedLD);
        } catch (bytes memory) {
            uint256 rate = IDecimalConversionRate(oft).decimalConversionRate();
            uint256 amount = (sendParam.amountLD / rate) * rate;
            return (amount, amount);
        }
    }

    /**
     * @dev Executes the message composed by the bridge adapter on the source chain.
     * @param _from The address of the OFT (oft or adapter) sending the composed message.
     * unused param _guid The message GUID.
     * @param _message The composed message.
     * unused param _executor The address that executes the message.
     * unused param _extraData Extra data provided by the executor.
     */
    function lzCompose(
        address _from,
        bytes32, /*_guid*/
        bytes calldata _message,
        address, /*_executor*/
        bytes calldata /*_extraData*/
    ) external payable {
        address bridgeToken = IOFT(_from).token();
        if (!oftLookup[_from].permissioned) revert OnlyPermissionedOft();
        if (oftLookup[_from].bridgeToken != bridgeToken) revert InvalidBridgeToken();
        if (address(IOAppCore(_from).endpoint()) != msg.sender) revert OnlyLzEndpoint();

        bytes memory composeMsg = OFTComposeMsgCodec.composeMsg(_message);
        uint256 amount = OFTComposeMsgCodec.amountLD(_message);

        emit ReceivedOft(bridgeToken, amount);

        (
            SwapInstructions memory postBridge,
            address target,
            address paymentOperator,
            bytes memory payload,
            address refund,
            bytes32 txId
        ) = abi.decode(composeMsg, (SwapInstructions, address, address, bytes, address, bytes32));

        if (postBridge.swapParams.tokenIn != bridgeToken) {
            postBridge.swapParams.tokenIn = bridgeToken;
        }

        if (amount != postBridge.swapParams.amountIn) {
            postBridge.swapParams.amountIn = amount;
        }

        uint256 value = 0;
        if (postBridge.swapParams.tokenIn == address(0)) {
            value = amount;
        } else if (IERC20(postBridge.swapParams.tokenIn).allowance(address(this), utb) < postBridge.swapParams.amountIn) {
            SafeERC20.forceApprove(IERC20(postBridge.swapParams.tokenIn), utb, postBridge.swapParams.amountIn);
        }

        try IUTB(utb).receiveFromBridge{value: value}(postBridge, target, paymentOperator, payload, refund, ID, txId) {}
        catch (bytes memory) {
            _refundUser(refund, postBridge.swapParams.tokenIn, amount);
        }
    }

    /**
     * @dev Builds the parameters for sending the underlying token and composed message.
     * @param bridgeCall Specifies the amount, destination chain, and post-bridge instructions.
     * @param bridgeToken The address of the underlying token being bridged.
     * @param oft The address of the OFT responsible for transferring the underlying token.
     */
    function _getSendParam(BridgeCall calldata bridgeCall, address bridgeToken, address oft) private view returns (SendParam memory sendParam){
        if (!oftLookup[oft].permissioned) revert OnlyPermissionedOft();
        if (oftLookup[oft].bridgeToken != bridgeToken) revert InvalidBridgeToken();
        bytes32 dstRouter = OFTComposeMsgCodec.addressToBytes32(destinationBridgeAdapter[bridgeCall.dstChainId]);

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(gasForRelay, 0)
            .addExecutorLzComposeOption(0, _getDstGas(bridgeCall.additionalArgs), 0);

        bytes memory bridgePayload = abi.encode(
            bridgeCall.postBridge, bridgeCall.target, bridgeCall.paymentOperator, bridgeCall.payload, bridgeCall.refund, bridgeCall.txId
        );

        sendParam = SendParam({
            dstEid: lzIdLookup[bridgeCall.dstChainId],
            to: dstRouter,
            amountLD: bridgeCall.amount,
            minAmountLD: bridgeCall.amount,
            extraOptions: options,
            composeMsg: bridgePayload,
            oftCmd: ""
        });

        (sendParam.amountLD, sendParam.minAmountLD) = _quoteOFT(oft, sendParam);
    }

    /**
     * @dev Refunds the specified amount of tokens or native value to the user.
     * @param user The address of the user being refunded.
     * @param token The address of the token being refunded.
     * @param amount The amount of tokens being refunded.
     */
    function _refundUser(address user, address token, uint256 amount) private {
        if ( amount > 0 ) {
            if (token == address(0)) {
                (bool success, ) = user.call{value: amount}("");
                if (!success) revert RefundFailed();
            } else {
                SafeERC20.safeTransfer(IERC20(token), user, amount);
            }
            emit RefundIssued(user, token, amount);
        }
    }

    /**
     * @dev Receives native value, reverts if the calling OFT has not been permissioned.
     */
    receive() external payable {
        if (oftLookup[msg.sender].bridgeToken != address(0) || !oftLookup[msg.sender].permissioned) {
            revert OnlyPermissionedOft();
        }
    }
}
