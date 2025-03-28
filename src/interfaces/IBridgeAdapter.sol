// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {SwapInstructions} from "../CommonTypes.sol";

interface IBridgeAdapter {

    error NoDstBridge();

    struct BridgeCall {
        uint256 amount;
        SwapInstructions postBridge;
        uint256 dstChainId;
        address target;
        address paymentOperator;
        bytes payload;
        bytes additionalArgs;
        address refund;
        bytes32 txId;
    }

    function ID() external returns (uint8);

    function getBridgeToken(
        bytes calldata additionalArgs
    ) external returns (address);

    function bridge(BridgeCall memory bridgeCall) external payable;
}
