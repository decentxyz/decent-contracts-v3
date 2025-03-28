// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

library SwapDirection {
    uint8 constant EXACT_IN = 0;
    uint8 constant EXACT_OUT = 1;
}

struct SwapParams {
    uint256 amountIn;
    uint256 amountOut;
    uint256 dustOut;
    address tokenIn;
    address tokenOut;
    uint8 direction;
    address refund;
    bytes additionalArgs;
}

struct SwapInstructions {
    uint8 swapperId;
    SwapParams swapParams;
}

struct SwapAndExecuteInstructions {
    SwapInstructions swapInstructions;
    address target;
    address paymentOperator;
    address refund;
    uint256 executionFee;
    bytes payload;
    bytes32 txId;
}

struct BridgeInstructions {
    SwapInstructions preBridge;
    SwapInstructions postBridge;
    uint8 bridgeId;
    uint256 dstChainId;
    address target;
    address paymentOperator;
    address refund;
    bytes payload;
    bytes additionalArgs;
    bytes32 txId;
}

struct FeeData {
    bytes4 appId;
    bytes4 affiliateId;
    uint256 bridgeFee;
    uint256 deadline;
    uint256 chainId;
    Fee[] appFees;
}

struct Fee {
    address recipient;
    address token;
    uint amount;
}
