// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// forge contracts
import "forge-std/Script.sol";
import "forge-std/console2.sol";

// bridge contracts
import {DecentBridgeExecutor} from "../src/DecentBridgeExecutor.sol";
import {DecentEthRouter} from "../src/DecentEthRouter.sol";
import {DcntEth} from "../src/DcntEth.sol";

// utb contracts
import {UTB} from "../src/UTB.sol";
import {UTBExecutor} from "../src/UTBExecutor.sol";
import {UTBFeeManager} from "../src/UTBFeeManager.sol";
import {UniSwapper} from "../src/swappers/UniSwapper.sol";
import {AnySwapper} from "../src/swappers/AnySwapper.sol";
import {DecentBridgeAdapter} from "../src/bridge_adapters/DecentBridgeAdapter.sol";
import {StargateBridgeAdapter} from "../src/bridge_adapters/StargateBridgeAdapter.sol";
import {OftBridgeAdapter} from "../src/bridge_adapters/OftBridgeAdapter.sol";
import {YieldOftBridgeAdapter} from "../src/bridge_adapters/YieldOftBridgeAdapter.sol";
import {HyperlaneBridgeAdapter} from "../src/bridge_adapters/HyperlaneBridgeAdapter.sol";
import {Withdrawable} from "../src/utils/Withdrawable.sol";

// base script
import {BridgeTasks} from "./Bridge.s.sol";
import {AdapterTasks} from "./Adapters.s.sol";

// eip contracts
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract UTBTasks is BridgeTasks, AdapterTasks {
    struct UTBConfig {
        bool decentBridge;
        bool stargateBridge;
        bool oftBridge;
        bool yieldOftBridge;
        bool hyperlaneBridge;
        bool uniswap;
        bool anyswap;
    }

    function _deployUtb()
        internal
        returns (
            UTB utb,
            UTBExecutor utbExecutor,
            UTBFeeManager utbFeeManager,
            UniSwapper uniSwapper,
            AnySwapper anySwapper,
            DecentBridgeAdapter decentBridgeAdapter,
            StargateBridgeAdapter stargateBridgeAdapter,
            OftBridgeAdapter oftBridgeAdapter,
            YieldOftBridgeAdapter yieldOftBridgeAdapter,
            HyperlaneBridgeAdapter hyperlaneBridgeAdapter
        )
    {
        UTBConfig memory utbConfig = abi.decode(vm.envBytes("UTB_CONFIG"), (UTBConfig));

        utb = new UTB();
        utbExecutor = new UTBExecutor();
        utbFeeManager = new UTBFeeManager(vm.addr(SIGNER_PRIVATE_KEY));

        if (utbConfig.uniswap) uniSwapper = _deployUniSwapper();
        if (utbConfig.anyswap) anySwapper = _deployAnySwapper();
        if (utbConfig.decentBridge) decentBridgeAdapter = _deployDecentBridgeAdapter();
        if (utbConfig.stargateBridge) stargateBridgeAdapter = _deployStargateBridgeAdapter();
        if (utbConfig.oftBridge) oftBridgeAdapter = _deployOftBridgeAdapter();
        if (utbConfig.yieldOftBridge) yieldOftBridgeAdapter = _deployYieldOftBridgeAdapter();
        if (utbConfig.hyperlaneBridge) hyperlaneBridgeAdapter = _deployHyperlaneBridgeAdapter();
    }

    function _configureUtb(address utb, address utbExecutor, address utbFeeManager) internal {
        string memory chain = vm.envString("CHAIN");
        address wrapped = wrappedLookup[chain];

        UTB(payable(utb)).setWrapped(payable(wrapped));

        _configureUtbExecutor(utbExecutor, utb);
        _configureUtbFeeManager(utbFeeManager, utb);
    }

    function _configureUtbExecutor(address utbExecutor, address utb) internal {
        UTBExecutor(utbExecutor).setOperator(utb);
        UTB(payable(utb)).setExecutor(utbExecutor);
    }

    function _configureUtbFeeManager(address utbFeeManager, address utb) internal {
        UTBFeeManager(utbFeeManager).setSigner(vm.addr(SIGNER_PRIVATE_KEY));
        UTB(payable(utb)).setFeeManager(payable(utbFeeManager));
    }
}

contract Deploy is UTBTasks {
    function run() external {
        UTBConfig memory utbConfig = abi.decode(vm.envBytes("UTB_CONFIG"), (UTBConfig));
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        vm.startBroadcast(account);

        if (utbConfig.decentBridge) {
            (
                DecentBridgeExecutor decentBridgeExecutor,
                DecentEthRouter decentEthRouter,
                DcntEth dcntEth
            ) = _deployBridge();

            logDeployment("DecentBridgeExecutor", address(decentBridgeExecutor));
            logDeployment("DecentEthRouter", address(decentEthRouter));
            logDeployment("DcntEth", address(dcntEth));
        }

        (
            UTB utb,
            UTBExecutor utbExecutor,
            UTBFeeManager utbFeeManager,
            UniSwapper uniSwapper,
            AnySwapper anySwapper,
            DecentBridgeAdapter decentBridgeAdapter,
            StargateBridgeAdapter stargateBridgeAdapter,
            OftBridgeAdapter oftBridgeAdapter,
            YieldOftBridgeAdapter yieldOftBridgeAdapter,
            HyperlaneBridgeAdapter hyperlaneBridgeAdapter
        ) = _deployUtb();

        vm.stopBroadcast();

        logDeployment("UTB", address(utb));
        logDeployment("UTBExecutor", address(utbExecutor));
        logDeployment("UTBFeeManager", address(utbFeeManager));

        if (utbConfig.uniswap) logDeployment("UniSwapper", address(uniSwapper));
        if (utbConfig.anyswap) logDeployment("AnySwapper", address(anySwapper));

        if (utbConfig.decentBridge) logDeployment("DecentBridgeAdapter", address(decentBridgeAdapter));
        if (utbConfig.stargateBridge) logDeployment("StargateBridgeAdapter", address(stargateBridgeAdapter));
        if (utbConfig.oftBridge) logDeployment("OftBridgeAdapter", address(oftBridgeAdapter));
        if (utbConfig.yieldOftBridge) logDeployment("YieldOftBridgeAdapter", address(yieldOftBridgeAdapter));
        if (utbConfig.hyperlaneBridge) logDeployment("HyperlaneBridgeAdapter", address(hyperlaneBridgeAdapter));
    }
}

contract Configure is UTBTasks {
    function _configureBridge() internal {
        string memory chain = vm.envString("CHAIN");

        address dcntEth = _getDeployment(chain, "DcntEth");
        address decentEthRouter = _getDeployment(chain, "DecentEthRouter");
        address decentBridgeExecutor = _getDeployment(chain, "DecentBridgeExecutor");

        _configureBridge(dcntEth, decentEthRouter, decentBridgeExecutor);
    }

    function _configureUtb() internal {
        string memory chain = vm.envString("CHAIN");

        address utb = _getDeployment(chain, "UTB");
        address utbExecutor = _getDeployment(chain, "UTBExecutor");
        address utbFeeManager = _getDeployment(chain, "UTBFeeManager");

        _configureUtb(utb, utbExecutor, utbFeeManager);
    }

    function _configureSwappers(UTBConfig memory utbConfig) internal {
        string memory chain = vm.envString("CHAIN");

        address utb = _getDeployment(chain, "UTB");

        if (utbConfig.uniswap) {
            address uniSwapper = _getDeployment(chain, "UniSwapper");
            _configureUniSwapper(uniSwapper, utb);
        }

        if (utbConfig.anyswap) {
            address anySwapper = _getDeployment(chain, "AnySwapper");
            _configureAnySwapper(anySwapper, utb);
        }
    }

    function _configureBridgeAdapters(UTBConfig memory utbConfig) internal {
        string memory chain = vm.envString("CHAIN");

        address utb = _getDeployment(chain, "UTB");

        if (utbConfig.decentBridge) {
            address decentBridgeAdapter = _getDeployment(chain, "DecentBridgeAdapter");
            address decentEthRouter = _getDeployment(chain, "DecentEthRouter");
            address decentBridgeExecutor = _getDeployment(chain, "DecentBridgeExecutor");
            _configureDecentBridgeAdapter(decentBridgeAdapter, utb, decentEthRouter, decentBridgeExecutor);
        }

        if (utbConfig.stargateBridge) {
            address stargateBridgeAdapter = _getDeployment(chain, "StargateBridgeAdapter");
            _configureStargateBridgeAdapter(stargateBridgeAdapter, utb);
        }

        if (utbConfig.oftBridge) {
            address oftBridgeAdapter = _getDeployment(chain, "OftBridgeAdapter");
            _configureOftBridgeAdapter(oftBridgeAdapter, utb);
        }

        if (utbConfig.yieldOftBridge) {
            address yieldOftBridgeAdapter = _getDeployment(chain, "YieldOftBridgeAdapter");
            _configureYieldOftBridgeAdapter(yieldOftBridgeAdapter, utb);
        }

        if (utbConfig.hyperlaneBridge) {
            address hyperlaneBridgeAdapter = _getDeployment(chain, "HyperlaneBridgeAdapter");
            _configureHyperlaneBridgeAdapter(hyperlaneBridgeAdapter, utb);
        }
    }

    function run() external {
        UTBConfig memory utbConfig = abi.decode(vm.envBytes("UTB_CONFIG"), (UTBConfig));
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        vm.startBroadcast(account);

        if (utbConfig.decentBridge) {
            _configureBridge();
        }

        _configureUtb();

        _configureSwappers(utbConfig);

        _configureBridgeAdapters(utbConfig);

        vm.stopBroadcast();
    }
}

contract Connect is UTBTasks {
    function _connectDecentBridge(string memory dst) internal {
        string memory src = vm.envString("SRC");

        address srcDcntEth = _getDeployment(src, "DcntEth");
        address dstDcntEth = _getDeployment(dst, "DcntEth");

        address srcDecentEthRouter = _getDeployment(src, "DecentEthRouter");
        address dstDecentEthRouter = _getDeployment(dst, "DecentEthRouter");

        uint32 dstLzV2Id = lzV2IdLookup[dst];

        _connectDecentBridge(srcDcntEth, dstDcntEth, srcDecentEthRouter, dstDecentEthRouter, dstLzV2Id);
    }

    function _connectBridgeAdapters(UTBConfig memory utbConfig, string memory dst) internal {
        string memory src = vm.envString("SRC");

        uint32 dstLzV2Id = lzV2IdLookup[dst];
        uint256 dstChainId = chainIdLookup[dst];
        uint8 dstDecimals = decimalsLookup[dst];

        if (utbConfig.decentBridge) {
            address srcDecentBridgeAdapter = _getDeployment(src, "DecentBridgeAdapter");
            address dstDecentBridgeAdapter = _getDeployment(dst, "DecentBridgeAdapter");

            _connectDecentBridgeAdapter(
                srcDecentBridgeAdapter,
                dstDecentBridgeAdapter,
                dstChainId,
                dstLzV2Id,
                dstDecimals
            );
        }

        if (utbConfig.stargateBridge) {
            address srcStargateBridgeAdapter = _getDeployment(src, "StargateBridgeAdapter");
            address dstStargateBridgeAdapter = _getDeployment(dst, "StargateBridgeAdapter");
            uint16 dstLzV1Id = lzV1IdLookup[dst];

            _connectStargateBridgeAdapter(
                srcStargateBridgeAdapter,
                dstStargateBridgeAdapter,
                dstChainId,
                dstLzV1Id,
                dstDecimals
            );
        }

        if (utbConfig.oftBridge) {
            address srcOftBridgeAdapter = _getDeployment(src, "OftBridgeAdapter");
            address dstOftBridgeAdapter = _getDeployment(dst, "OftBridgeAdapter");

            _connectOftBridgeAdapter(
                srcOftBridgeAdapter,
                dstOftBridgeAdapter,
                dstChainId,
                dstLzV2Id,
                dstDecimals
            );
        }

        if (utbConfig.yieldOftBridge) {
            address srcYieldOftBridgeAdapter = _getDeployment(src, "YieldOftBridgeAdapter");
            address dstYieldOftBridgeAdapter = _getDeployment(dst, "YieldOftBridgeAdapter");

            _connectYieldOftBridgeAdapter(
                srcYieldOftBridgeAdapter,
                dstYieldOftBridgeAdapter,
                dstChainId,
                dstLzV2Id,
                dstDecimals
            );
        }

        if (utbConfig.hyperlaneBridge) {
            address srcHyperlaneBridgeAdapter = _getDeployment(src, "HyperlaneBridgeAdapter");
            address dstHyperlaneBridgeAdapter = _getDeployment(dst, "HyperlaneBridgeAdapter");
            uint256 dstHyperlaneDomainId = uint256(hyperlaneDomainIdLookup[dst]);

            _connectHyperlaneBridgeAdapter(
                srcHyperlaneBridgeAdapter,
                dstHyperlaneBridgeAdapter,
                dstHyperlaneDomainId,
                dstDecimals
            );
        }
    }

    function run() external {
        UTBConfig[] memory utbConfigs = abi.decode(vm.envBytes("UTB_CONFIGS"), (UTBConfig[]));
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));
        string[] memory dstChains = abi.decode(vm.envBytes("DST_CHAINS"), (string[]));

        vm.startBroadcast(account);

        for (uint256 i = 0; i < dstChains.length; i++) {
            if (utbConfigs[i].decentBridge) {
                _connectDecentBridge(dstChains[i]);
            }

            _connectBridgeAdapters(utbConfigs[i], dstChains[i]);
        }

        vm.stopBroadcast();
    }
}

contract Withdraw is UTBTasks {
    function run() external {
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));
        address withdrawable = vm.envAddress("CONTRACT");
        address to = vm.envAddress("TO");
        uint256 amount = vm.envUint("AMOUNT");

        vm.startBroadcast(account);

        Withdrawable(withdrawable).withdraw(to, amount);

        vm.stopBroadcast();
    }
}
