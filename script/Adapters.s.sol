// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// utb contracts
import {UTB} from "../src/UTB.sol";
import {UniSwapper} from "../src/swappers/UniSwapper.sol";
import {AnySwapper} from "../src/swappers/AnySwapper.sol";
import {DecentBridgeAdapter} from "../src/bridge_adapters/DecentBridgeAdapter.sol";
import {StargateBridgeAdapter} from "../src/bridge_adapters/StargateBridgeAdapter.sol";
import {OftBridgeAdapter} from "../src/bridge_adapters/OftBridgeAdapter.sol";
import {YieldOftBridgeAdapter} from "../src/bridge_adapters/YieldOftBridgeAdapter.sol";
import {HyperlaneBridgeAdapter} from "../src/bridge_adapters/HyperlaneBridgeAdapter.sol";

// base script
import {BaseScript} from "./BaseScript.s.sol";

contract AdapterTasks is BaseScript {

    function _deployUniSwapper() internal returns (UniSwapper) {
        return new UniSwapper();
    }

    function _deployAnySwapper() internal returns (AnySwapper) {
        return new AnySwapper();
    }

    function _deployDecentBridgeAdapter() internal returns (DecentBridgeAdapter) {
        string memory chain = vm.envString("CHAIN");
        bool gasIsEth = gasEthLookup[chain];
        address weth = wethLookup[chain];
        address bridgeToken = gasIsEth ? address(0) : weth;
        uint8 decimals = decimalsLookup[chain];

        return new DecentBridgeAdapter(gasIsEth, decimals, bridgeToken);
    }

    function _deployStargateBridgeAdapter() internal returns (StargateBridgeAdapter) {
        string memory chain = vm.envString("CHAIN");
        uint8 decimals = decimalsLookup[chain];
        address stargateFactory = sgFactoryLookup[chain];

        return new StargateBridgeAdapter(decimals, stargateFactory);
    }

    function _deployOftBridgeAdapter() internal returns (OftBridgeAdapter) {
        string memory chain = vm.envString("CHAIN");
        uint8 decimals = decimalsLookup[chain];

        return new OftBridgeAdapter(decimals);
    }

    function _deployYieldOftBridgeAdapter() internal returns (YieldOftBridgeAdapter) {
        string memory chain = vm.envString("CHAIN");
        uint8 decimals = decimalsLookup[chain];

        return new YieldOftBridgeAdapter(decimals);
    }

    function _deployHyperlaneBridgeAdapter() internal returns (HyperlaneBridgeAdapter) {
        string memory chain = vm.envString("CHAIN");
        uint8 decimals = decimalsLookup[chain];
        address hyperlaneMailbox = hyperlaneMailboxLookup[chain];

        return new HyperlaneBridgeAdapter(decimals, hyperlaneMailbox);
    }

    function _configureUniSwapper(address _uniSwapper, address utb) internal {
        string memory chain = vm.envString("CHAIN");
        address wrapped = wrappedLookup[chain];
        address uniRouter = uniRouterLookup[chain];

        UniSwapper uniSwapper = UniSwapper(payable(_uniSwapper));
        uniSwapper.setWrapped(payable(wrapped));
        uniSwapper.setRouter(uniRouter);
        uniSwapper.setUtb(utb);
        UTB(payable(utb)).registerSwapper(address(uniSwapper));
    }

    function _configureAnySwapper(address _anySwapper, address utb) internal {
        string memory chain = vm.envString("CHAIN");
        address wrapped = wrappedLookup[chain];

        AnySwapper anySwapper = AnySwapper(payable(_anySwapper));
        anySwapper.setWrapped(payable(wrapped));
        anySwapper.setUtb(utb);
        UTB(payable(utb)).registerSwapper(address(anySwapper));
    }

    function _configureDecentBridgeAdapter(
        address _decentBridgeAdapter,
        address utb,
        address decentEthRouter,
        address decentBridgeExecutor
    ) internal {
        DecentBridgeAdapter decentBridgeAdapter = DecentBridgeAdapter(payable(_decentBridgeAdapter));
        decentBridgeAdapter.setUtb(utb);
        decentBridgeAdapter.setRouter(decentEthRouter);
        decentBridgeAdapter.setBridgeExecutor(decentBridgeExecutor);
        UTB(payable(utb)).registerBridge(_decentBridgeAdapter);
    }

    function _configureStargateBridgeAdapter(
        address _stargateBridgeAdapter,
        address utb
    ) internal {
        string memory chain = vm.envString("CHAIN");
        address stargateComposer = sgComposerLookup[chain];
        address stargateEth = sgEthLookup[chain];

        StargateBridgeAdapter stargateBridgeAdapter = StargateBridgeAdapter(payable(_stargateBridgeAdapter));
        stargateBridgeAdapter.setUtb(utb);
        stargateBridgeAdapter.setStargateComposer(stargateComposer);
        stargateBridgeAdapter.setStargateEth(stargateEth);
        stargateBridgeAdapter.setBridgeExecutor(stargateComposer);
        UTB(payable(utb)).registerBridge(_stargateBridgeAdapter);
    }

    function _configureOftBridgeAdapter(
        address _oftBridgeAdapter,
        address utb
    ) internal {
        OftBridgeAdapter oftBridgeAdapter = OftBridgeAdapter(payable(_oftBridgeAdapter));
        oftBridgeAdapter.setUtb(utb);
        UTB(payable(utb)).registerBridge(_oftBridgeAdapter);
    }

    function _configureYieldOftBridgeAdapter(
        address _yieldOftBridgeAdapter,
        address utb
    ) internal {
        YieldOftBridgeAdapter yieldOftBridgeAdapter = YieldOftBridgeAdapter(payable(_yieldOftBridgeAdapter));
        yieldOftBridgeAdapter.setUtb(utb);
        UTB(payable(utb)).registerBridge(_yieldOftBridgeAdapter);
    }

    function _configureHyperlaneBridgeAdapter(
        address _hyperlaneBridgeAdapter,
        address utb
    ) internal {
        HyperlaneBridgeAdapter hyperlaneBridgeAdapter = HyperlaneBridgeAdapter(payable(_hyperlaneBridgeAdapter));
        hyperlaneBridgeAdapter.setUtb(utb);
        UTB(payable(utb)).registerBridge(_hyperlaneBridgeAdapter);
    }

    function _connectDecentBridgeAdapter(
        address _srcDecentBridgeAdapter,
        address dstDecentBridgeAdapter,
        uint256 dstChainId,
        uint32 dstLzV2Id,
        uint8 dstDecimals
    ) internal {
        DecentBridgeAdapter srcDecentBridgeAdapter = DecentBridgeAdapter(payable(_srcDecentBridgeAdapter));
        srcDecentBridgeAdapter.registerRemoteBridgeAdapter(dstChainId, dstLzV2Id, dstDecimals, dstDecentBridgeAdapter);
    }

    function _connectStargateBridgeAdapter(
        address _srcStargateBridgeAdapter,
        address dstStargateBridgeAdapter,
        uint256 dstChainId,
        uint16 dstLzV1Id,
        uint8 dstDecimals
    ) internal {
        StargateBridgeAdapter srcStargateBridgeAdapter = StargateBridgeAdapter(payable(_srcStargateBridgeAdapter));
        srcStargateBridgeAdapter.registerRemoteBridgeAdapter(dstChainId, dstLzV1Id, dstDecimals, dstStargateBridgeAdapter);
    }

    function _connectOftBridgeAdapter(
        address _srcOftBridgeAdapter,
        address dstOftBridgeAdapter,
        uint256 dstChainId,
        uint32 dstLzV2Id,
        uint8 dstDecimals
    ) internal {
        OftBridgeAdapter srcOftBridgeAdapter = OftBridgeAdapter(payable(_srcOftBridgeAdapter));
        srcOftBridgeAdapter.registerRemoteBridgeAdapter(dstChainId, dstLzV2Id, dstDecimals, dstOftBridgeAdapter);
    }

    function _connectYieldOftBridgeAdapter(
        address _srcYieldOftBridgeAdapter,
        address dstYieldOftBridgeAdapter,
        uint256 dstChainId,
        uint32 dstLzV2Id,
        uint8 dstDecimals
    ) internal {
        YieldOftBridgeAdapter srcYieldOftBridgeAdapter = YieldOftBridgeAdapter(payable(_srcYieldOftBridgeAdapter));
        srcYieldOftBridgeAdapter.registerRemoteBridgeAdapter(dstChainId, dstLzV2Id, dstDecimals, dstYieldOftBridgeAdapter);
    }

    function _connectHyperlaneBridgeAdapter(
        address _srcHyperlaneBridgeAdapter,
        address dstHyperlaneBridgeAdapter,
        uint256 dstChainId,
        uint8 dstDecimals
    ) internal {
        HyperlaneBridgeAdapter srcHyperlaneBridgeAdapter = HyperlaneBridgeAdapter(payable(_srcHyperlaneBridgeAdapter));
        srcHyperlaneBridgeAdapter.registerRemoteBridgeAdapter(dstChainId, dstDecimals, dstHyperlaneBridgeAdapter);
    }

    function _addHyperlaneWarpRoute(
        address _hyperlane,
        uint32 destinationDomain,
        address localTokenRouter,
        address localToken,
        address remoteToken
    ) internal {
        HyperlaneBridgeAdapter hyperlane = HyperlaneBridgeAdapter(payable(_hyperlane));
        hyperlane.addWarpRoute(
            destinationDomain,
            localTokenRouter,
            localToken,
            remoteToken
        );
    }
}

contract DeployAnySwapper is AdapterTasks {
    function run() external {
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        vm.startBroadcast(account);

        AnySwapper anySwapper = new AnySwapper();

        vm.stopBroadcast();

        logDeployment("AnySwapper", address(anySwapper));
    }
}

contract ConfigureAnySwapper is AdapterTasks {
    function run() external {
        string memory chain = vm.envString("CHAIN");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        address utb = _getDeployment(chain, "UTB");
        address anySwapper = _getDeployment(chain, "AnySwapper");

        vm.startBroadcast(account);

        _configureAnySwapper(anySwapper, utb);

        vm.stopBroadcast();
    }
}

contract SetUniSwapperRouter is AdapterTasks {
    function run() public {
        string memory chain = vm.envString("CHAIN");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        address _uniSwapper = _getDeployment(chain, 'UniSwapper');
        UniSwapper uniSwapper = UniSwapper(payable(_uniSwapper));
        address uniRouter = uniRouterLookup[chain];

        vm.startBroadcast(account);

        uniSwapper.setRouter(uniRouter);

        vm.stopBroadcast();
    }
}

contract DeployOftBridgeAdapter is AdapterTasks {
    function run() external {
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        vm.startBroadcast(account);

        OftBridgeAdapter oftBridgeAdapter = _deployOftBridgeAdapter();

        vm.stopBroadcast();

        logDeployment("OftBridgeAdapter", address(oftBridgeAdapter));
    }
}

contract ConfigureOftBridgeAdapter is AdapterTasks {
    function run() external {
        string memory chain = vm.envString("CHAIN");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        address utb = _getDeployment(chain, "UTB");
        address oftBridgeAdapter = _getDeployment(chain, "OftBridgeAdapter");

        vm.startBroadcast(account);

        _configureOftBridgeAdapter(oftBridgeAdapter, utb);

        vm.stopBroadcast();
    }
}

contract DeployYieldOftBridgeAdapter is AdapterTasks {
    function run() external {
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        vm.startBroadcast(account);

        YieldOftBridgeAdapter yieldOftBridgeAdapter = _deployYieldOftBridgeAdapter();

        vm.stopBroadcast();

        logDeployment("YieldOftBridgeAdapter", address(yieldOftBridgeAdapter));
    }
}

contract ConfigureYieldOftBridgeAdapter is AdapterTasks {
    function run() external {
        string memory chain = vm.envString("CHAIN");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        address utb = _getDeployment(chain, "UTB");
        address yieldOftBridgeAdapter = _getDeployment(chain, "YieldOftBridgeAdapter");

        vm.startBroadcast(account);

        _configureYieldOftBridgeAdapter(yieldOftBridgeAdapter, utb);

        vm.stopBroadcast();
    }
}

contract DeployHyperlaneBridgeAdapter is AdapterTasks {
    function run() external {
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        vm.startBroadcast(account);

        HyperlaneBridgeAdapter hyperlaneBridgeAdapter = _deployHyperlaneBridgeAdapter();

        vm.stopBroadcast();

        logDeployment("HyperlaneBridgeAdapter", address(hyperlaneBridgeAdapter));
    }
}

contract ConfigureHyperlaneBridgeAdapter is AdapterTasks {
    function run() external {
        string memory chain = vm.envString("CHAIN");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        address utb = _getDeployment(chain, "UTB");
        address hyperlaneBridgeAdapter = _getDeployment(chain, "HyperlaneBridgeAdapter");

        vm.startBroadcast(account);

        _configureHyperlaneBridgeAdapter(hyperlaneBridgeAdapter, utb);

        vm.stopBroadcast();
    }
}

contract AddHyperlaneWarpRoute is AdapterTasks {
    function run() external {
        string memory src = vm.envString("SRC");
        string memory dst = vm.envString("DST");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        uint32 destinationDomain = hyperlaneDomainIdLookup[dst];
        address localTokenRouter = vm.envAddress("LOCAL_TOKEN_ROUTER");
        address localToken = vm.envAddress("LOCAL_TOKEN");
        address remoteToken = vm.envAddress("REMOTE_TOKEN");

        address hyperlane = _getDeployment(src, "HyperlaneBridgeAdapter");

        vm.startBroadcast(account);

        _addHyperlaneWarpRoute(
            hyperlane,
            destinationDomain,
            localTokenRouter,
            localToken,
            remoteToken
        );

        vm.stopBroadcast();
    }
}
