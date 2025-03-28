// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {SwapInstructions, Fee, FeeData, BridgeInstructions, SwapAndExecuteInstructions} from "../CommonTypes.sol";

interface IUTB {

    struct TxInfo {
        uint256 amountIn;
        address tokenIn;
        address tokenOut;
        address target;
        bytes4 affiliateId;
        Fee[] fees;
    }

    event Swapped(
        bytes32 indexed txId,
        bytes4 indexed appId,
        TxInfo txInfo
    );

    event BridgeCalled(
        bytes32 indexed txId,
        bytes4 indexed appId,
        uint256 indexed dstChainId,
        TxInfo txInfo
    );

    event ReceivedFromBridge(bytes32 indexed txId);

    event SetExecutor(address executor);
    event SetWrapped(address wrapped);
    event SetFeeManager(address feeManager);
    event SetIsActive(bool isActive);
    event RegisteredSwapper(address swapper);
    event RegisteredBridgeAdapter(address bridge);

    /// @notice Thrown when protocol fees cannot be collected
    error ProtocolFeeCannotBeFetched();

    /// @notice Thrown when UTB is paused
    error UTBPaused();

    /// @notice Thrown when not enough native is passed for swap
    error NotEnoughNative();

    /// @notice Thrown when receive from bridge is not called from a bridge adapter
    error OnlyBridgeAdapter();

    /// @notice Thrown when native is transferred and the sender is not wrapped native
    error OnlyWrapped();

    /// @notice Thrown when the fee deadline has been passed
    error ExpiredFees();

    /// @notice Thrown when the fee data has invalid parameters
    error InvalidFees();

    /// @notice Thrown when the token mismatch
    error InvalidSwapParams();

    /// @notice Thrown when there is an unsuccessful refund
    error RefundFailed();

    /**
     * @dev Swaps currency from the incoming to the outgoing token and executes a transaction with payment.
     * @param instructions The token swap data and payment transaction payload.
     * @param feeData The bridge fee in native, as well as utb fee tokens and amounts.
     * @param signature The ECDSA signature to verify the fee structure.
     */
    function swapAndExecute(
        SwapAndExecuteInstructions memory instructions,
        FeeData memory feeData,
        bytes memory signature
    ) external payable;

    /**
     * @dev Bridges funds in native or ERC20 and a payment transaction payload to the destination chain
     * @param instructions The bridge data, token swap data, and payment transaction payload.
     * @param feeData The bridge fee in native, as well as utb fee tokens and amounts.
     * @param signature The ECDSA signature to verify the fee structure.
     */
    function bridgeAndExecute(
        BridgeInstructions memory instructions,
        FeeData memory feeData,
        bytes memory signature
    ) external payable;

    /**
     * @dev Receives funds from the bridge adapter, executes a swap, and executes a payment transaction.
     * @param postBridge The swapper ID and calldata to execute a swap.
     * @param target The address of the target contract for the payment transaction.
     * @param paymentOperator The operator address for payment transfers requiring ERC20 approvals.
     * @param payload The calldata to execute the payment transaction.
     * @param refund The account receiving any refunds, typically the EOA which initiated the transaction.
     */
    function receiveFromBridge(
        SwapInstructions memory postBridge,

        address target,
        address paymentOperator,
        bytes memory payload,
        address refund,
        uint8 bridgeId,
        bytes32 txId
    ) external payable;

    /**
     * @dev Registers and maps a bridge adapter to a bridge adapter ID.
     * @param bridge The address of the bridge adapter.
     */
    function registerBridge(address bridge) external;

    /**
     * @dev Registers and maps a swapper to a swapper ID.
     * @param swapper The address of the swapper.
     */
    function registerSwapper(address swapper) external;

    function setExecutor(address _executor) external;

    function setFeeManager(address _feeManager) external;

    function setWrapped(address _wrapped) external;
}
