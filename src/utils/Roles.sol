// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;
import {AccessControlDefaultAdminRules} from "@openzeppelin/contracts/access/AccessControlDefaultAdminRules.sol";

abstract contract Roles is AccessControlDefaultAdminRules {
    constructor(address admin) AccessControlDefaultAdminRules(
      24 hours /* initialDelay */,
      admin /* initialDefaultAdmin */
    ) {}

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Only admin");
        _;
    }
}
