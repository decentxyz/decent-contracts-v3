// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {Roles} from "./utils/Roles.sol";
import {Withdrawable} from "./utils/Withdrawable.sol";

contract UTBOwned is Roles, Withdrawable {
    address payable public utb;

    event SetUtb(address utb);

    error InvalidUtb();

    constructor() Roles(msg.sender) {}

    /**
     * @dev Limit access to the approved UTB.
     */
    modifier onlyUtb() {
        require(msg.sender == utb, "Only utb");
        _;
    }

    /**
     * @dev Sets the approved UTB.
     * @param _utb The address of the UTB.
     */
    function setUtb(address _utb) public onlyAdmin {
        if (_utb == address(0) || _utb.code.length == 0) revert InvalidUtb();
        utb = payable(_utb);
        emit SetUtb(_utb);
    }
}
