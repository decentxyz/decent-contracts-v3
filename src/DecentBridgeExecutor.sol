// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IWETH} from "./interfaces/IWETH.sol";
import {IDecentBridgeExecutor} from "./interfaces/IDecentBridgeExecutor.sol";
import {Operable} from "./utils/Operable.sol";
import {Allowable} from "./utils/Allowable.sol";
import {Roles} from "./utils/Roles.sol";
import {Withdrawable} from "./utils/Withdrawable.sol";

contract DecentBridgeExecutor is IDecentBridgeExecutor, Operable, Allowable, Withdrawable {
    IWETH public weth;
    bool public gasCurrencyIsEth; // for chains that use ETH as gas currency

    modifier onlyWeth() {
        if (msg.sender != address(weth)) revert OnlyWeth();
        _;
    }

    constructor(address _weth, bool gasIsEth) Roles(msg.sender) {
        weth = IWETH(payable(_weth));
        gasCurrencyIsEth = gasIsEth;
    }

    function setWeth(address _weth) public onlyAdmin {
        weth = IWETH(payable(_weth));
    }

    /**
     * @dev helper function for execute
     * @param refundAddress the refund address
     * @param target target contract
     * @param amount amount of the in eth
     * @param callPayload payload for the tx
     */
    function _executeWeth(
        address refundAddress,
        address target,
        uint256 amount,
        bytes memory callPayload
    ) private {
        uint256 balanceBefore = weth.balanceOf(address(this));
        weth.approve(target, amount);

        (bool success, ) = target.call(callPayload);

        if (!success) {
            weth.transfer(refundAddress, amount);
            return;
        }

        uint256 remainingAfterCall = amount -
            (balanceBefore - weth.balanceOf(address(this)));

        // refund the sender with excess WETH
        weth.transfer(refundAddress, remainingAfterCall);
    }

    /**
     * @dev helper function for execute
     * @param refundAddress the address to be refunded
     * @param target target contract
     * @param amount amount of the transaction
     * @param callPayload payload for the tx
     */
    function _executeEth(
        address refundAddress,
        address target,
        uint256 amount,
        bytes memory callPayload
    ) private {
        weth.withdraw(amount);
        (bool success, ) = target.call{value: amount}(callPayload);
        if (!success) {
            (success, ) = payable(refundAddress).call{value: amount}("");
            if (!success) revert TransferFailed();
        }
    }

    /// @inheritdoc IDecentBridgeExecutor
    function execute(
        address refundAddress,
        address target,
        bool deliverEth,
        uint256 amount,
        bytes memory callPayload
    ) public onlyOperator onlyAllowed(target) {
        weth.transferFrom(msg.sender, address(this), amount);

        if (!gasCurrencyIsEth || !deliverEth) {
            _executeWeth(refundAddress, target, amount, callPayload);
        } else {
            _executeEth(refundAddress, target, amount, callPayload);
        }
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable onlyWeth {}
}
