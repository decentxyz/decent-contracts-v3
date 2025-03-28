// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

interface IStargatePool {
    function convertRate() external returns (uint256 convertRate);
}
