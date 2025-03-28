// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IWETH is IERC20 {

    function deposit() external payable;

    function withdraw(uint) external;
}
