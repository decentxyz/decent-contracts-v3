// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// forge contracts
import {console2} from "forge-std/console2.sol";

// base script
import {BaseScript} from "./BaseScript.s.sol";

contract LogConfig is BaseScript {
    function run() view public {
        string memory chain = vm.envString("CHAIN");

        console2.log(string.concat('CONFIG FOR CHAIN: ', chain));
        console2.log('gasEthLookup', gasEthLookup[chain]);
        console2.log('wethLookup', wethLookup[chain]);
        console2.log('lzV1EndpointLookup', address(lzV1EndpointLookup[chain]));
        console2.log('lzV1IdLookup', lzV1IdLookup[chain]);
        console2.log('lzV2EndpointLookup', address(lzV2EndpointLookup[chain]));
        console2.log('lzV2IdLookup', lzV2IdLookup[chain]);
        console2.log('chainIdLookup', chainIdLookup[chain]);
        console2.log('wrappedLookup', wrappedLookup[chain]);
        console2.log('uniRouterLookup', uniRouterLookup[chain]);
        console2.log('sgComposerLookup', sgComposerLookup[chain]);
        console2.log('sgEthLookup', sgEthLookup[chain]);
        console2.log('decentBridgeToken', gasEthLookup[chain] ? address(0) : wethLookup[chain]);
        console2.log('hyperlaneMailboxLookup', hyperlaneMailboxLookup[chain]);
        console2.log('hyperlaneDomainIdLookup', hyperlaneDomainIdLookup[chain]);
    }
}

contract Simulate is BaseScript {
    function run() public {
        address from = vm.envAddress("FROM");
        address to = vm.envAddress("TO");
        uint value = vm.envUint("VALUE");
        bytes memory data = vm.envBytes("CALLDATA");

        vm.prank(from);
        (to.call{value: value}(data));
    }
}
