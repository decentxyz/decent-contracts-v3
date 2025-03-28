// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*@@@@@@@       @@@@@@@@@
 @@@@@@@@@       @@@@@@@@@
  @@@@@@@@@       @@@@@@@@@
   @@@@@@@@@       @@@@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@
     @@@@@  HYPERLANE  @@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@
   @@@@@@@@@       @@@@@@@@@
  @@@@@@@@@       @@@@@@@@@
 @@@@@@@@@       @@@@@@@@@
@@@@@@@@@       @@@@@@@@*/

// ============ External Imports ============
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {CallLib} from "@hyperlane-xyz/contracts/middleware/libs/Call.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {TypeCasts} from "@hyperlane-xyz/contracts/libs/TypeCasts.sol";
import {StandardHookMetadata} from "@hyperlane-xyz/contracts/hooks/libs/StandardHookMetadata.sol";
import {TokenRouter} from "@hyperlane-xyz/contracts/token/libs/TokenRouter.sol";
import {HypERC20Collateral} from "@hyperlane-xyz/contracts/token/HypERC20Collateral.sol";
import {InterchainAccountRouter} from "@hyperlane-xyz/contracts/middleware/InterchainAccountRouter.sol";
import {IMailbox} from "@hyperlane-xyz/contracts/interfaces/IMailbox.sol";
import {IMessageRecipient} from "@hyperlane-xyz/contracts/interfaces/IMessageRecipient.sol";

// ============ Internal Imports ============
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {BaseAdapter} from "./BaseAdapter.sol";
import {IUTB} from "../interfaces/IUTB.sol";
import {SwapInstructions, SwapParams} from "../CommonTypes.sol";

/**
 * @title Hyperlane Bridge Adapter
 * @author Abacus Works
 * @notice This contract implements the bridge adapter for the Hyperlane protocol
 */
contract HyperlaneBridgeAdapter is IBridgeAdapter, BaseAdapter, IMessageRecipient {
    using TypeCasts for address;
    using TypeCasts for bytes32;
    using Address for address;
    using Address for address payable;

    // ============ Events ============

    /// @notice Emitted when the utbExecutor.execute call reverts
    event UTBExecutorCallReverted();

    /// @notice Emitted when a remote bridge adapter is registered
    event RegisteredRemoteBridgeAdapter(uint256 dstChainId, uint8 dstDecimals, address dstBridgeAdapter);

    /// @notice Emitted when a warp route is added
    event AddedWarpRoute(uint32 destinationDomain, address localTokenRouter, address localToken, address remoteToken);

    /// @notice Emitted when a warp route is removed
    event RemovedWarpRoute(uint32 destinationDomain, address localTokenRouter);

    // ============ Errors ============
    error OnlyPermissionedMailbox();
    error OnlyPermissionedRouter();
    error InvalidMailbox();
    error InvalidSender();
    error NoEnrolledRouter();
    error InsufficientMsgValue();
    error InvalidRemoteToken();

    // ============ Structs ============

    // Helper struct for the remoteCall function
    struct CallParams {
        BridgeCall bridgeCall;
        TokenRouter tokenRouter;
        uint32 destinationDomain;
        address to;
        uint256 value;
        uint256 callGasLimit;
        uint256 callQuote;
    }

    /// helper struct bridging on source
    struct BridgeParams {
        TokenRouter tokenRouter;
        address bridgeToken;
        address remoteToken;
        uint256 bridgeValue;
        address remoteBridgeAdapter;
    }

    /// helper struct for gas quotes
    struct GasQuotes {
        uint256 tokenQuote;
        uint256 callQuote;
    }

    // warp route permissions
    struct WarpRoute {
        bool permissioned;
        address localToken;
    }

    // ============ Constants ============

    /// @notice The ID of the hyperlane bridge adapter
    uint8 public constant ID = 6;

    // ============ State Variables ============

    /// @notice The mailbox for the local chain
    mapping(address mailbox => bool permissioned) mailboxes;
    /// @notice The destination bridge adapters for each destination chain
    mapping(uint256 chainId => address remoteBridgeAdapter) public destinationBridgeAdapters;
    /// @notice The permissions for each warp route, only outbound
    mapping(address router => WarpRoute) public warpRoutes;
    /// @notice The remote token for each destination chain
    mapping(address router => mapping(uint256 chainId => address remoteToken)) public remoteTokens;

    // ============ Modifiers ============

    modifier onlyPermissionedMailbox() {
        if (!mailboxes[msg.sender]) revert OnlyPermissionedMailbox();
        _;
    }

    /// @notice Validates the swap params do not exceed the precision of the destination chain.
    /// @dev Same as BaseAdapter remotePrecision modifier but accepts memory instead of calldata
    /// @param dstChainId The chain ID of the destination chain.
    /// @param swapParams Struct containing the parameters for the destinatiion swap.
    modifier validRemotePrecision(uint256 dstChainId, SwapParams memory swapParams) {
        uint256 rate = decimals >= remoteDecimals[dstChainId]
            ? 10 ** (decimals - remoteDecimals[dstChainId])
            : 10 ** (remoteDecimals[dstChainId] - decimals);

        uint256 amountHP = swapParams.amountOut - swapParams.dustOut;
        uint256 dust = amountHP - ((amountHP / rate) * rate);

        if (dust > 0) revert RemotePrecisionExceeded();
        _;
    }

    // ============ Constructor ============

    constructor(uint8 _decimals, address _mailbox) BaseAdapter() {
        if (_mailbox == address(0)) revert InvalidMailbox();
        decimals = _decimals;
        mailboxes[_mailbox] = true;
    }

    // ============ External Functions ============

    /// @notice Register a remote bridge adapter for a destination chain
    /// @param dstChainId the destination chain ID
    /// @param dstDecimals the number of decimals on the destination chain
    /// @param destinationBridgeAdapter the address of the destination bridge adapter
    function registerRemoteBridgeAdapter(uint256 dstChainId, uint8 dstDecimals, address destinationBridgeAdapter)
        external
        onlyAdmin
    {
        destinationBridgeAdapters[dstChainId] = destinationBridgeAdapter;
        remoteDecimals[dstChainId] = dstDecimals;
        emit RegisteredRemoteBridgeAdapter(dstChainId, dstDecimals, destinationBridgeAdapter);
    }

    /// @notice Deregister a remote bridge adapter for a destination chain
    /// @param dstChainId the destination chain ID
    function deregisterRemoteBridgeAdapter(uint256 dstChainId) external onlyAdmin {
        destinationBridgeAdapters[dstChainId] = address(0);
    }

    /// @notice Add a warp route to the hyperlane bridge adapter (for the admin)
    /// @param destinationDomain the destination domain
    /// @param localTokenRouter the local hyperlane token router (HypNative/HypErc20Collateral/HypERC20)
    /// @param localToken the local token being sent over the warp route (native/erc20)
    /// @param remoteToken the remote destination token being received over the warp route (native/erc20)
    function addWarpRoute(uint32 destinationDomain, address localTokenRouter, address localToken, address remoteToken)
        external
        onlyAdmin
    {
        warpRoutes[localTokenRouter] = WarpRoute({
            permissioned: true,
            localToken: localToken
        });

        remoteTokens[localTokenRouter][uint256(destinationDomain)] = remoteToken;

        address remoteBridgeAdapter = destinationBridgeAdapters[destinationDomain];
        if (remoteBridgeAdapter == address(0)) revert NoDstBridge();

        emit AddedWarpRoute(destinationDomain, localTokenRouter, localToken, remoteToken);
    }

    /// @notice Remove a warp route from the hyperlane bridge adapter (for the admin)
    /// @param destinationDomain the destination domain
    /// @param localTokenRouter the local hyperlane token router (HypNative/HypErc20Collateral/HypERC20)
    function removeWarpRoute(uint32 destinationDomain, address localTokenRouter) external onlyAdmin {
        warpRoutes[localTokenRouter] = WarpRoute({
            permissioned: false,
            localToken: address(0)
        });

        remoteTokens[localTokenRouter][uint256(destinationDomain)] = address(0);

        emit RemovedWarpRoute(destinationDomain, localTokenRouter);
    }

    /// @notice Add a mailbox to the hyperlane bridge adapter (for the admin)
    /// @param _mailbox the mailbox
    function addMailbox(address _mailbox) external onlyAdmin {
        if (_mailbox == address(0)) revert InvalidMailbox();
        mailboxes[_mailbox] = true;
    }

    /// @notice Remove a mailbox from the hyperlane bridge adapter (for the admin)
    /// @param _mailbox the mailbox
    function removeMailbox(address _mailbox) external onlyAdmin {
        if (_mailbox == address(0)) revert InvalidMailbox();
        mailboxes[_mailbox] = false;
    }

    /// @notice Quote the gas payment for a warp route
    /// @param dstChainId the destination chain ID
    /// @param tokenRouter the token router
    /// @param msgBody the message body
    /// @param callGasLimit the call gas limit to override for second dispatch delivery
    /// @return gas the gas payment for the warp route
    /// @dev callGasLimit should be adjusted to be sufficient for the swap and call on the destination chain, otherwise relayer won't deliver the message
    function quoteGasPayment(uint256 dstChainId, address tokenRouter, bytes memory msgBody, uint256 callGasLimit)
        public
        view
        returns (uint256 gas)
    {
        address remoteBridgeAdapter = destinationBridgeAdapters[dstChainId];
        GasQuotes memory quotes =
            _getGasQuotes(dstChainId, TokenRouter(tokenRouter), remoteBridgeAdapter, msgBody, callGasLimit);
        return quotes.tokenQuote + quotes.callQuote;
    }

    /// @notice Bridge a warp route
    /// @param bridgeCall the bridge call
    function bridge(BridgeCall memory bridgeCall)
        public
        payable
        onlyUtb
        validRemotePrecision(bridgeCall.dstChainId, bridgeCall.postBridge.swapParams)
    {
        BridgeParams memory params = _validateAndTransfer(bridgeCall);
        (, uint256 callGasLimit,) = _decodeAdditionalArgs(bridgeCall.additionalArgs);

        GasQuotes memory quotes = _getGasQuotes(
            bridgeCall.dstChainId,
            params.tokenRouter,
            params.remoteBridgeAdapter,
            _encodeMessageBody(bridgeCall),
            callGasLimit
        );

        if (msg.value < params.bridgeValue + quotes.tokenQuote + quotes.callQuote) {
            revert InsufficientMsgValue();
        }

        _executeBridgeCall(
            bridgeCall,
            params.tokenRouter,
            params.remoteToken,
            params.bridgeValue,
            quotes.tokenQuote,
            quotes.callQuote,
            params.remoteBridgeAdapter,
            callGasLimit
        );
    }

    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message)
        external
        payable
        virtual
        override
        onlyPermissionedMailbox
    {
        if (_sender != destinationBridgeAdapters[uint256(_origin)].addressToBytes32()) revert InvalidSender();

        (
            SwapInstructions memory postBridge,
            address target,
            address paymentOperator,
            bytes memory payload,
            address refund,
            bytes32 txId
        ) = abi.decode(_message, (SwapInstructions, address, address, bytes, address, bytes32));

        uint256 value;
        uint256 initialBalance;
        uint256 finalBalance;

        if (postBridge.swapParams.tokenIn == address(0)) {
            initialBalance = address(this).balance - postBridge.swapParams.amountIn;
            value = postBridge.swapParams.amountIn;
        } else {
            initialBalance = IERC20(postBridge.swapParams.tokenIn).balanceOf(address(this)) - postBridge.swapParams.amountIn;
            SafeERC20.safeApprove(IERC20(postBridge.swapParams.tokenIn), utb, postBridge.swapParams.amountIn);
        }

        // execute the post bridge call
        try IUTB(utb).receiveFromBridge{value: value}(postBridge, target, paymentOperator, payload, refund, ID, txId) {
            if (postBridge.swapParams.tokenIn == address(0)) {
                finalBalance = address(this).balance;
            } else {
                finalBalance = IERC20(postBridge.swapParams.tokenIn).balanceOf(address(this));
            }
            uint256 refundAmount = finalBalance - initialBalance;
            if (refundAmount > 0) {
                _refundUser(refund, postBridge.swapParams.tokenIn, refundAmount);
            }
        } catch {
            _refundUser(refund, postBridge.swapParams.tokenIn, postBridge.swapParams.amountIn);
            emit UTBExecutorCallReverted();
        }

        if (postBridge.swapParams.tokenIn != address(0)) {
            SafeERC20.safeApprove(IERC20(postBridge.swapParams.tokenIn), utb, 0);
        }
    }

    // ============ Public Functions ============

    /// @inheritdoc IBridgeAdapter
    function getBridgeToken(bytes calldata additionalArgs) public pure returns (address token) {
        (token,,) = _decodeAdditionalArgs(additionalArgs);
    }

    function getRouter(bytes calldata additionalArgs) public pure returns (address router) {
        (,,router) = _decodeAdditionalArgs(additionalArgs);
    }

    // ============ Internal Functions ============

    /**
     * @notice Validates bridge parameters and performs token transfer and approval.
     * @param bridgeCall The bridge call parameters.
     * @return params The validated bridge parameters.
     */
    function _validateAndTransfer(BridgeCall memory bridgeCall) internal returns (BridgeParams memory params) {
        (params.tokenRouter, params.bridgeToken, params.remoteToken) = _validateBridgeParams(bridgeCall);

        params.bridgeValue = _transferAndApprove(params.bridgeToken, bridgeCall.amount, address(params.tokenRouter));

        params.remoteBridgeAdapter = destinationBridgeAdapters[bridgeCall.dstChainId];
    }

    /// @notice Validates and returns parameters needed for bridging
    /// @param bridgeCall The bridge call parameters
    /// @return tokenRouter The token router
    /// @return bridgeToken The bridge token address
    /// @return remoteToken The remote token address
    function _validateBridgeParams(BridgeCall memory bridgeCall)
        internal
        view
        returns (TokenRouter tokenRouter, address bridgeToken, address remoteToken)
    {
        bridgeToken = this.getBridgeToken(bridgeCall.additionalArgs);
        tokenRouter = TokenRouter(this.getRouter(bridgeCall.additionalArgs));
        if (!warpRoutes[address(tokenRouter)].permissioned) revert OnlyPermissionedRouter();
        remoteToken = remoteTokens[address(tokenRouter)][bridgeCall.dstChainId];

        if (address(tokenRouter) == address(0)) revert NoEnrolledRouter();
        if (destinationBridgeAdapters[bridgeCall.dstChainId] == address(0)) revert NoDstBridge();
        if (remoteToken != bridgeCall.postBridge.swapParams.tokenIn) revert InvalidRemoteToken();
    }

    /**
     * @notice Retrieves gas quotes for token transfer and interchain account operations.
     * @param dstChainId The destination chain ID.
     * @param tokenRouter The token router.
     * @param msgBody The message body.
     * @return quotes The gas quotes.
     */
    function _getGasQuotes(
        uint256 dstChainId,
        TokenRouter tokenRouter,
        address remoteBridgeAdapter,
        bytes memory msgBody,
        uint256 callGasLimit
    ) internal view returns (GasQuotes memory quotes) {
        quotes.tokenQuote = tokenRouter.quoteGasPayment(uint32(dstChainId));
        quotes.callQuote = tokenRouter.mailbox().quoteDispatch(
            uint32(dstChainId),
            remoteBridgeAdapter.addressToBytes32(),
            msgBody,
            StandardHookMetadata.overrideGasLimit(callGasLimit)
        );
    }

    /// @notice Execute the token router transfer and mailbox dispatch
    /// @param bridgeCall The bridge call parameters
    /// @param tokenRouter The token router
    /// @param remoteToken The remote token
    /// @param bridgeValue The bridge value
    /// @param tokenQuote The token quote for gas payment
    /// @param callQuote The call quote for interchain account operations
    /// @param remoteBridgeAdapter The remote bridge adapter
    function _executeBridgeCall(
        BridgeCall memory bridgeCall,
        TokenRouter tokenRouter,
        address remoteToken,
        uint256 bridgeValue,
        uint256 tokenQuote,
        uint256 callQuote,
        address remoteBridgeAdapter,
        uint256 callGasLimit
    ) internal {
        uint32 destinationDomain = uint32(bridgeCall.dstChainId);

        tokenRouter.transferRemote{value: tokenQuote + bridgeValue}(
            destinationDomain, remoteBridgeAdapter.addressToBytes32(), bridgeCall.amount
        );

        // update the post bridge swap params to the bridged amount, no slippage required
        if (bridgeCall.amount != bridgeCall.postBridge.swapParams.amountIn) {
            bridgeCall.postBridge.swapParams.amountIn = bridgeCall.amount;
        }

        CallParams memory params = CallParams({
            bridgeCall: bridgeCall,
            tokenRouter: tokenRouter,
            destinationDomain: destinationDomain,
            to: destinationBridgeAdapters[bridgeCall.dstChainId],
            value: remoteToken == address(0) ? bridgeCall.amount : 0,
            callGasLimit: callGasLimit,
            callQuote: callQuote
        });

        _remoteCall(params, remoteBridgeAdapter);
    }

    /// @notice Make a remote call to the remote bridge adapter to execute the post bridge call
    /// @param params the remote call parameters
    /// @param remoteBridgeAdapter the remote bridge adapter
    function _remoteCall(CallParams memory params, address remoteBridgeAdapter) internal {
        bytes memory msgBody = _encodeMessageBody(params.bridgeCall);

        params.tokenRouter.mailbox().dispatch{value: params.callQuote}(
            params.destinationDomain,
            remoteBridgeAdapter.addressToBytes32(),
            msgBody,
            StandardHookMetadata.overrideGasLimit(params.callGasLimit)
        );
    }

    /// @notice Encode the message body for the remote call
    /// @param bridgeCall The bridge call parameters
    /// @return The encoded message body
    function _encodeMessageBody(BridgeCall memory bridgeCall) internal pure returns (bytes memory) {
        return abi.encode(
            bridgeCall.postBridge,
            bridgeCall.target,
            bridgeCall.paymentOperator,
            bridgeCall.payload,
            bridgeCall.refund,
            bridgeCall.txId
        );
    }

    /// @notice Transfer and approve the bridge token
    /// @param bridgeToken the bridge token
    /// @param amount the amount
    /// @param tokenRouter the token router
    /// @return native the amount of native
    function _transferAndApprove(address bridgeToken, uint256 amount, address tokenRouter)
        internal
        returns (uint256 native)
    {
        if (bridgeToken == address(0)) {
            native = amount;
        } else {
            SafeERC20.safeTransferFrom(IERC20(bridgeToken), msg.sender, address(this), amount);
            IERC20(bridgeToken).approve(tokenRouter, amount);
        }
    }

    /// @notice Refund the user
    /// @param user the user
    /// @param token the token
    /// @param amount the amount
    function _refundUser(address user, address token, uint256 amount) internal {
        if (token == address(0)) {
            payable(user).sendValue(amount);
        } else {
            SafeERC20.safeTransfer(IERC20(token), user, amount);
        }
    }

    /// @notice Decode the additional arguments
    /// @param additionalArgs the additional arguments
    /// @return token the token used for the bridge on source
    /// @return callGasLimit the call gas limit to override for second dispatch delivery
    /// @return router the local hyperlane token router
    function _decodeAdditionalArgs(bytes memory additionalArgs)
        internal
        pure
        returns (address token, uint256 callGasLimit, address router)
    {
        (token, callGasLimit, router) = abi.decode(additionalArgs, (address, uint256, address));
    }

    // ============ Receive Functions ============

    receive() external payable {}
}
