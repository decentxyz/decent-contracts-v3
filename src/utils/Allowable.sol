// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {Roles} from "./Roles.sol";

abstract contract Allowable is Roles {
    mapping(address => bool) public disallowed;

    error Disallowed();

    modifier onlyAllowed(address addr) {
        if (disallowed[addr]) revert Disallowed();
        _;
    }

    function disallow(address addr) external onlyAdmin {
        disallowed[addr] = true;
    }

    function allow(address addr) external onlyAdmin {
        disallowed[addr] = false;
    }
}
