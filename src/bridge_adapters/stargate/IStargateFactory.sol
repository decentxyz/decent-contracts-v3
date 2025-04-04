// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

interface IStargateFactory {
    function getPool(uint256 poolId) external returns (address pool);
}
