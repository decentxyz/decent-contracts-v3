// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IUTBExecutor} from "./interfaces/IUTBExecutor.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Operable} from "./utils/Operable.sol";
import {Allowable} from "./utils/Allowable.sol";
import {Roles} from "./utils/Roles.sol";
import {Withdrawable} from "./utils/Withdrawable.sol";

contract UTBExecutor is IUTBExecutor, Operable, Allowable, Withdrawable {

    constructor() Roles(msg.sender) {}

    /// @inheritdoc IUTBExecutor
    function execute(
        address target,
        address paymentOperator,
        bytes memory payload,
        address token,
        uint amount,
        address refund,
        uint256 executionFee
    ) public payable onlyOperator onlyAllowed(target) {
        bool success;
        if (token == address(0)) {
            (success, ) = target.call{value: amount + executionFee}(payload);
            if (!success) {
                (success, ) = payable(refund).call{value: amount}("");
                if (!success) revert TransferFailed();
            }
            return;
        }

        uint initBalance = IERC20(token).balanceOf(address(this));

        SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);
        SafeERC20.forceApprove(IERC20(token), paymentOperator, amount);

        (success, ) = target.call{value: executionFee}(payload);
        if (!success) revert ExecutionFailed();

        uint remainingBalance = IERC20(token).balanceOf(address(this)) -
            initBalance;

        if (remainingBalance == 0) {
            return;
        }

        SafeERC20.safeTransfer(IERC20(token), refund, remainingBalance);

        emit ExecutionSucceeded();
    }
}
