// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// forge contracts
import "forge-std/console2.sol";

// base fixture
import {BaseFixture} from "./BaseFixture.sol";

contract ArbitrumFixture is BaseFixture {

    constructor() {
        TEST.CONFIG = Config({
            rpc: vm.rpcUrl("arbitrum"),
            srcChainId: 42161,
            dstChainId: 1,
            srcLzV1Id: 110,
            dstLzV1Id: 101,
            srcLzV2Id: 30110,
            dstLzV2Id: 30101,
            isGasEth: true,
            weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            uniswap: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45,
            stargateComposer: 0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9,
            stargateFactory: 0x55bDb4164D28FBaF0898e0eF14a589ac09Ac9970,
            stargateEth: 0x82CbeCF39bEe528B5476FE6d1550af59a9dB6Fc0
        });

        _initialize();
    }
}
