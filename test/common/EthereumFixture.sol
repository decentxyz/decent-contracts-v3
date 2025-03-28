// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// forge contracts
import "forge-std/console2.sol";

// base fixture
import {BaseFixture} from "./BaseFixture.sol";

contract EthereumFixture is BaseFixture {

    constructor() {
        TEST.CONFIG = Config({
            rpc: vm.rpcUrl("ethereum"),
            srcChainId: 1,
            dstChainId: 42161,
            srcLzV1Id: 101,
            dstLzV1Id: 110,
            srcLzV2Id: 30101,
            dstLzV2Id: 30110,
            isGasEth: true,
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            uniswap: 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45,
            stargateComposer: 0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9,
            stargateFactory: 0x06D538690AF257Da524f25D0CD52fD85b1c2173E,
            stargateEth: 0x72E2F4830b9E45d52F80aC08CB2bEC0FeF72eD9c
        });

        _initialize();
    }
}
