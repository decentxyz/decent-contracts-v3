// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {UTBOwned} from "../UTBOwned.sol";
import {SwapParams} from "../CommonTypes.sol";

contract BaseAdapter is UTBOwned {
    mapping(uint256 chainId => uint8 decimals) public remoteDecimals;
    uint8 public immutable decimals;
    address public bridgeExecutor;

    event RegisteredRemoteBridgeAdapter(
        uint256 dstChainId,
        uint32 dstLzId,
        uint8 dstDecimals,
        address dstBridgeAdapter
    );

    event SetBridgeExecutor(address executor);
    event SetGasForRelay(uint128 before, uint128 gasForRelay);

    constructor() UTBOwned() {}

    error InvalidChainId();
    error InvalidLzId();
    error InvalidDecimals();
    error InvalidBridgeAdapter();
    error InvalidExecutor();
    error RemotePrecisionExceeded();
    error OnlyExecutor();

    /**
     * @dev Validates parameters for a remote LayerZero bridge adapter.
     * @param dstChainId The chain ID of the destination chain.
     * @param dstLzId The LayerZero endpoint ID for the destination chain.
     * @param dstDecimals The number of decimals on the destination chain.
     * @param dstBridgeAdapter The address of the bridge adapter to register.
     */
    modifier onlyValidLzAdapter(
        uint256 dstChainId,
        uint32 dstLzId,
        uint8 dstDecimals,
        address dstBridgeAdapter
    ) {
        if (dstChainId == 0) revert InvalidChainId();
        if (dstLzId == 0) revert InvalidLzId();
        if (dstDecimals < 6 || dstDecimals > 39) revert InvalidDecimals();
        if (dstBridgeAdapter == address(0)) revert InvalidBridgeAdapter();
        _;
    }

    /**
     * @dev Validates the swap params do not exceed the precision of the destination chain.
     * @param dstChainId The chain ID of the destination chain.
     * @param swapParams Struct containing the parameters for the destinatiion swap.
     */
    modifier remotePrecision(uint256 dstChainId, SwapParams calldata swapParams) {
        uint256 rate = decimals >= remoteDecimals[dstChainId]
            ? 10 ** (decimals - remoteDecimals[dstChainId])
            : 10 ** (remoteDecimals[dstChainId] - decimals);

        uint256 amountHP = swapParams.amountOut - swapParams.dustOut;
        uint256 dust = amountHP - ((amountHP / rate) * rate);

        if (dust > 0) revert RemotePrecisionExceeded();
        _;
    }

    /**
     * @dev Restricts access to bridging to the approved bridge executor.
     */
    modifier onlyExecutor() {
        if (msg.sender != address(bridgeExecutor)) revert OnlyExecutor();
        _;
    }

    /**
     * @dev Sets the approved bridge executor.
     * @param _bridgeExecutor The address of the bridge executor being approved.
     */
    function setBridgeExecutor(address _bridgeExecutor) public onlyAdmin {
        if (_bridgeExecutor == address(0)) revert InvalidExecutor();
        bridgeExecutor = _bridgeExecutor;
        emit SetBridgeExecutor(_bridgeExecutor);
    }
}
