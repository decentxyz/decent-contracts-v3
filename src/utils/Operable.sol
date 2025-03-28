// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {Roles} from "./Roles.sol";

abstract contract Operable is Roles {
    address public operator;

    /**
     * @dev Limit access to the approved operator.
     */
    modifier onlyOperator() {
        require(msg.sender == operator, "Only operator");
        _;
    }

    /**
     * @dev Sets the approved operator.
     * @param _operator The address of the operator.
     */
    function setOperator(address _operator) public onlyAdmin {
        operator = payable(_operator);
    }
}
