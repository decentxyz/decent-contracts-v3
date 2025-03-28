// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {Roles} from "./Roles.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Withdrawable is Roles {
    /// @notice Thrown when a native currency withdrawal fails
    error WithdrawalFailed();

    /// @notice Emitted when ERC20 tokens are withdrawn from the contract
    event WithdrawERC20(address token, address to, uint256 amount);

    /// @notice Thrown when recipient address is zero
    error InvalidRecipient();

    /// @notice Emitted when native currency is withdrawn from the contract
    event Withdraw(address to, uint256 amount);

    /**
     * @notice Allows admin to withdraw any ERC20 tokens stuck in the contract
     * @param token The ERC20 token address to withdraw
     * @param to The address to send the tokens to
     * @param amount The amount of tokens to withdraw
     */
    function withdrawERC20(address token, address to, uint256 amount) external onlyAdmin {
        if (to == address(0)) revert InvalidRecipient();
        SafeERC20.safeTransfer(IERC20(token), to, amount);
        emit WithdrawERC20(token, to, amount);
    }

    /**
     * @notice Allows admin to withdraw any native currency stuck in the contract
     * @param to The address to send the native currency to
     * @param amount The amount of native currency to withdraw
     */
    function withdraw(address to, uint256 amount) external onlyAdmin {
        if (to == address(0)) revert InvalidRecipient();
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert WithdrawalFailed();
        emit Withdraw(to, amount);
    }
}
