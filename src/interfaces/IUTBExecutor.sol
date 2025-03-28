// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

interface IUTBExecutor {

    event ExecutionSucceeded();

    error ExecutionFailed();

    error TransferFailed();

    /**
     * @dev Executes a payment transaction with native OR ERC20.
     * @param target The address of the target contract for the payment transaction.
     * @param paymentOperator The operator address for payment transfers requiring ERC20 approvals.
     * @param payload The calldata to execute the payment transaction.
     * @param token The token being transferred, zero address for native.
     * @param amount The amount of native or ERC20 being sent with the payment transaction.
     * @param refund The account receiving any refunds, typically the EOA that initiated the transaction.
     * @param executionFee Forwards additional native fees required for executing the payment transaction.
     */
    function execute(
        address target,
        address paymentOperator,
        bytes memory payload,
        address token,
        uint256 amount,
        address refund,
        uint256 executionFee
    ) external payable;
}
