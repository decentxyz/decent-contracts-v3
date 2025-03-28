// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IOFTV2} from "@layerzerolabs/solidity-examples/contracts/token/oft/v2/interfaces/IOFTV2.sol";

interface IDecentBridgeExecutor {

    error OnlyWeth();

    error TransferFailed();

    /**
     * @dev called upon receiving dcntEth in the DecentEthRouter
     * @param refundAddress the address to send refunds
     * @param target target contract
     * @param deliverEth delivers WETH if false
     * @param amount amount of the transaction
     * @param callPayload payload for the tx
     */
    function execute(
      address refundAddress,
      address target,
      bool deliverEth,
      uint256 amount,
      bytes memory callPayload
    ) external;
}
