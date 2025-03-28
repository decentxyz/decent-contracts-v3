// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// forge contracts
import "forge-std/console2.sol";

// base fixture
import {BaseFixture} from "./BaseFixture.sol";

contract InkFixture is BaseFixture {

    constructor() {
        TEST.CONFIG = Config({
            rpc: vm.rpcUrl("ink"),
            srcChainId: 57073,
            dstChainId: 1,
            srcLzV1Id: 339,
            dstLzV1Id: 101,
            srcLzV2Id: 30339,
            dstLzV2Id: 30101,
            isGasEth: true,
            weth: 0x4200000000000000000000000000000000000006,
            uniswap: 0x0000000000000000000000000000000000000000,
            stargateComposer: 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF, // TODO: deprecate sg v1
            stargateFactory: 0x0000000000000000000000000000000000000000,
            stargateEth: 0x0000000000000000000000000000000000000000
        });

        _initialize();
    }
}
