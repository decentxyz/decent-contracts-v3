// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

interface IDecentEthRouter {

    struct DecentBridgeCall {
        uint8 msgType;
        uint32 dstChainId;
        address toAddress;
        address refundAddress;
        uint256 amount;
        uint64 dstGasForCall;
        bool deliverEth;
        bytes payload;
    }

    event SetWeth(address weth);

    event SetExecutor(address executor);

    event SetGasForRelay(uint128 before, uint128 gasForRelay);

    event RegisteredDcntEth(address addr);

    event AddedDestinationBridge(uint32 dstChainId, address routerAddress);

    event BridgedPayload();

    event ReceivedPayload();

    event AddedLiquidity(uint256 amount);

    event RemovedLiquidity(uint256 amount);

    event SetRequireOperator(bool requireOperator);

    error OnlyDcntEth();

    error OnlyLzEndpoint();

    error OnlyEthChain();

    error OnlyBridgeOperator();

    error NotEnoughReserves();

    error InsufficientBalance();

    error OnlyWeth();

    error TransferFailed();

    function MT_ETH_TRANSFER() external view returns (uint8);

    function MT_ETH_TRANSFER_WITH_PAYLOAD() external view returns (uint8);

    /**
     * @dev Sets dcntEth to the router
     * @param _addr The address of the deployed DcntEth token
     */
    function registerDcntEth(address _addr) external;

    /**
     * @dev Adds a destination bridge for the bridge
     * @param _dstChainId The lz chainId
     * @param _routerAddress The router address on the dst chain
     */
    function addDestinationBridge(
        uint32 _dstChainId,
        address _routerAddress
    ) external;

    function estimateSendAndCallFee(
        uint8 msgType,
        uint32 _dstChainId,
        address _toAddress,
        address _refundAddress,
        uint _amount,
        uint64 _dstGasForCall,
        bool deliverEth,
        bytes memory payload
    ) external view returns (uint nativeFee, uint zroFee);

    /**
     * @param _dstChainId lz endpoint
     * @param _toAddress the destination address (i.e. dst bridge)
     * @param _refundAddress the refund address
     * @param _amount the amount being bridged
     * @param deliverEth if false, delivers WETH
     * @param _dstGasForCall the amount of dst gas
     * @param additionalPayload contains the refundAddress, zroPaymentAddress, and adapterParams
     */
    function bridgeWithPayload(
        uint32 _dstChainId,
        address _toAddress,
        address _refundAddress,
        uint _amount,
        bool deliverEth,
        uint64 _dstGasForCall,
        bytes memory additionalPayload
    ) external payable;

    /**
     * @param _dstChainId lz endpoint
     * @param _toAddress destination address
     * @param _refundAddress the address to be refunded
     * @param _amount the amount being bridge
     * @param _dstGasForCall the amount of dst gas
     * @param deliverEth if false, delivers WETH
     */
    function bridge(
        uint32 _dstChainId,
        address _toAddress,
        address _refundAddress,
        uint _amount,
        uint64 _dstGasForCall,
        bool deliverEth // if false, delivers WETH
    ) external payable;

    /**
     * @dev allows users to redeem all their dcntEth for ETH
     */
    function redeemEth() external;

    /**
     * @dev allows users to redeem all their dcntEth for WETH
     */
    function redeemWeth() external;

    /**
     * @dev allows admin to redeem dcntEth for ETH on behalf of an account
     * @param account The address to burn dcntEth from and send ETH to
     * @param amount The amount of ETH to withdraw
     */
    function redeemEthFor(address account, uint256 amount) external;

    /**
     * @dev allows admin to redeem dcntEth for WETH on behalf of an account
     * @param account The address to burn dcntEth from and send WETH to
     * @param amount The amount of WETH to withdraw
     */
    function redeemWethFor(address account, uint256 amount) external;

    /**
     * @dev adds bridge liquidity by paying ETH
     */
    function addLiquidityEth() external payable;

    /**
     * @dev withdraws a users bridge liquidity for ETH
     * @param amount The amount of ETH to withdraw
     */
    function removeLiquidityEth(uint256 amount) external;

    /**
     * @dev adds bridge liquidity by providing WETH
     * @param amount The amount of WETH to add
     */
    function addLiquidityWeth(uint256 amount) external;

    /**
     * @dev withdraws a users bridge liquidity for WETH
     * @param amount The amount of WETH to withdraw
     */
    function removeLiquidityWeth(uint256 amount) external;
}
