// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUTB} from "../interfaces/IUTB.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {SwapInstructions, SwapParams} from "../CommonTypes.sol";
import {IDecentEthRouter} from "../interfaces/IDecentEthRouter.sol";
import {BaseAdapter} from "./BaseAdapter.sol";

contract DecentBridgeAdapter is BaseAdapter, IBridgeAdapter {
    uint8 public constant ID = 0;
    mapping(uint256 chainId => address remoteBridgeAdapter) public destinationBridgeAdapter;
    IDecentEthRouter public router;
    mapping(uint256 chainId => uint32 lzId) public lzIdLookup;
    mapping(uint32 lzId => uint256 chainId) public chainIdLookup;
    bool public immutable gasIsEth;
    address public immutable bridgeToken;

    constructor(bool _gasIsEth, uint8 _decimals, address _bridgeToken) BaseAdapter() {
        gasIsEth = _gasIsEth;
        decimals = _decimals;
        bridgeToken = _bridgeToken;
    }

    function setRouter(address _router) public onlyAdmin {
        router = IDecentEthRouter(payable(_router));
    }

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

    function estimateFees(
        SwapInstructions memory postBridge,
        uint256 dstChainId,
        address target,
        uint64 dstGas,
        bytes memory payload
    ) public view returns (uint nativeFee, uint zroFee) {
        return
            router.estimateSendAndCallFee(
                router.MT_ETH_TRANSFER_WITH_PAYLOAD(),
                lzIdLookup[dstChainId],
                target,
                msg.sender,
                postBridge.swapParams.amountIn,
                dstGas,
                false,
                payload
            );
    }

    function getBridgeToken(
        bytes calldata /*additionalArgs*/
    ) external view returns (address) {
        return bridgeToken;
    }

    function bridge(
        BridgeCall calldata bridgeCall
    ) public payable onlyUtb remotePrecision(bridgeCall.dstChainId, bridgeCall.postBridge.swapParams) {
        if (destinationBridgeAdapter[bridgeCall.dstChainId] == address(0)) revert NoDstBridge();

        uint64 dstGas = abi.decode(bridgeCall.additionalArgs, (uint64));

        bytes memory bridgePayload = abi.encodeCall(
            this.receiveFromBridge,
            (
                bridgeCall.postBridge,
                bridgeCall.target,
                bridgeCall.paymentOperator,
                bridgeCall.payload,
                bridgeCall.refund,
                bridgeCall.txId
            )
        );

        if (!gasIsEth) {
            SafeERC20.safeTransferFrom(
                IERC20(bridgeToken),
                msg.sender,
                address(this),
                bridgeCall.amount
            );
            SafeERC20.forceApprove(IERC20(bridgeToken), address(router), bridgeCall.amount);
        }

        router.bridgeWithPayload{value: msg.value}(
            lzIdLookup[bridgeCall.dstChainId],
            destinationBridgeAdapter[bridgeCall.dstChainId],
            bridgeCall.refund,
            bridgeCall.amount,
            false,
            dstGas,
            bridgePayload
        );
    }

    function receiveFromBridge(
        SwapInstructions memory postBridge,
        address target,
        address paymentOperator,
        bytes memory payload,
        address refund,
        bytes32 txId
    ) public payable onlyExecutor {
        SafeERC20.safeTransferFrom(
            IERC20(postBridge.swapParams.tokenIn),
            msg.sender,
            address(this),
            postBridge.swapParams.amountIn
        );

        SafeERC20.forceApprove(
            IERC20(postBridge.swapParams.tokenIn),
            utb,
            postBridge.swapParams.amountIn
        );

        IUTB(utb).receiveFromBridge(
            postBridge,
            target,
            paymentOperator,
            payload,
            refund,
            ID,
            txId
        );
    }
}
