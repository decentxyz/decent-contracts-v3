// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// forge contracts
import "forge-std/console2.sol";

// base fixture
import {BaseFixture} from "./BaseFixture.sol";

contract ApeFixture is BaseFixture {

    constructor() {
        TEST.CONFIG = Config({
            rpc: vm.rpcUrl("ape"),
            srcChainId: 33139,
            dstChainId: 1,
            srcLzV1Id: 312,
            dstLzV1Id: 101,
            srcLzV2Id: 30312,
            dstLzV2Id: 30101,
            isGasEth: false,
            weth: 0x8073B2158AA023Dd7f8d4799C883B65DaF6baA57,
            uniswap: 0x0000000000000000000000000000000000000000,
            stargateComposer: makeAddr("StargateComposer"), // executor cannot be address(0)
            stargateFactory: 0x0000000000000000000000000000000000000000,
            stargateEth: 0x0000000000000000000000000000000000000000
        });

        _initialize();
    }
}
