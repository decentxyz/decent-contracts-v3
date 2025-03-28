// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// forge contracts
import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

// bridge contracts
import {DecentBridgeExecutor} from "../../src/DecentBridgeExecutor.sol";
import {DecentEthRouter} from "../../src/DecentEthRouter.sol";
import {DcntEth} from "../../src/DcntEth.sol";

// utb contracts
import {UTB} from "../../src/UTB.sol";
import {UTBExecutor} from "../../src/UTBExecutor.sol";
import {UTBFeeManager} from "../../src/UTBFeeManager.sol";
import {UniSwapper} from "../../src/swappers/UniSwapper.sol";
import {AnySwapper} from "../../src/swappers/AnySwapper.sol";
import {DecentBridgeAdapter} from "../../src/bridge_adapters/DecentBridgeAdapter.sol";
import {StargateBridgeAdapter} from "../../src/bridge_adapters/StargateBridgeAdapter.sol";
import {HyperlaneBridgeAdapter} from "../../src/bridge_adapters/HyperlaneBridgeAdapter.sol";
import {OftBridgeAdapter} from "../../src/bridge_adapters/OftBridgeAdapter.sol";
import {YieldOftBridgeAdapter} from "../../src/bridge_adapters/YieldOftBridgeAdapter.sol";

// hyperlane contracts
import {TypeCasts} from "@hyperlane-xyz/contracts/libs/TypeCasts.sol";
import {Mailbox} from "@hyperlane-xyz/contracts/Mailbox.sol";
import {MockMailbox} from "@hyperlane-xyz/contracts/mock/MockMailbox.sol";
import {TokenRouter} from "@hyperlane-xyz/contracts/token/libs/TokenRouter.sol";
import {HypERC20Collateral} from "@hyperlane-xyz/contracts/token/HypERC20Collateral.sol";
import {HypERC20} from "@hyperlane-xyz/contracts/token/HypERC20.sol";
import {HypNative} from "@hyperlane-xyz/contracts/token/HypNative.sol";
import {TestPostDispatchHook} from "@hyperlane-xyz/contracts/test/TestPostDispatchHook.sol";
import {TestInterchainGasPaymaster} from "@hyperlane-xyz/contracts/test/TestInterchainGasPaymaster.sol";
import {CallLib} from "@hyperlane-xyz/contracts/middleware/libs/Call.sol";

// layer zero contracts
import {TestHelper} from "../layerzero/TestHelper.sol";

// token contracts
import {IWETH} from "../../src/interfaces/IWETH.sol";

// mocks
import {MockErc20} from "../helpers/MockErc20.sol";
import {MockOft} from "../helpers/MockOft.sol";

contract BaseFixture is Test, TestHelper {
    using TypeCasts for address;

    uint8 constant DECIMALS = 18;

    TestInfo TEST;

    struct TestInfo {
        Config CONFIG;
        Deployment SRC;
        Deployment DST;
        Accounts EOA;
        LayerZero LZ;
        Hyperlane hyperlane;
    }

    struct Config {
        string rpc;
        uint256 srcChainId;
        uint256 dstChainId;
        uint16 srcLzV1Id;
        uint16 dstLzV1Id;
        uint32 srcLzV2Id;
        uint32 dstLzV2Id;
        bool isGasEth;
        address weth;
        address uniswap;
        address stargateComposer;
        address stargateFactory;
        address stargateEth;
    }

    struct Deployment {
        DecentBridgeExecutor decentBridgeExecutor;
        DecentEthRouter decentEthRouter;
        DcntEth dcntEth;
        UTB utb;
        UTBExecutor utbExecutor;
        UTBFeeManager utbFeeManager;
        UniSwapper uniSwapper;
        AnySwapper anySwapper;
        DecentBridgeAdapter decentBridgeAdapter;
        StargateBridgeAdapter stargateBridgeAdapter;
        HyperlaneBridgeAdapter hyperlaneBridgeAdapter;
        OftBridgeAdapter oftBridgeAdapter;
        YieldOftBridgeAdapter yieldOftBridgeAdapter;
        MockOft mockOft;
    }

    struct DecentBridgeDeployment {
        DecentBridgeExecutor decentBridgeExecutor;
        DecentEthRouter decentEthRouter;
        DcntEth dcntEth;
    }

    struct UTBDeployment {
        UTB utb;
        UTBExecutor utbExecutor;
        UTBFeeManager utbFeeManager;
        UniSwapper uniSwapper;
        AnySwapper anySwapper;
        DecentBridgeAdapter decentBridgeAdapter;
        StargateBridgeAdapter stargateBridgeAdapter;
        HyperlaneBridgeAdapter hyperlaneBridgeAdapter;
        OftBridgeAdapter oftBridgeAdapter;
        YieldOftBridgeAdapter yieldOftBridgeAdapter;
    }

    struct Accounts {
        address deployer;
        address feeSigner;
        address alice;
        address bob;
    }

    struct LayerZero {
        uint32 srcId;
        uint32 dstId;
    }

    struct Hyperlane {
        MockMailbox localMailbox;
        MockMailbox remoteMailbox;
        IERC20 primaryToken;
        IERC20 weth;
        HypERC20 warpSynthetic;
        HypERC20Collateral warpCollateral;
        HypERC20Collateral nativeCollateral;
        HypNative warpNative;
        HypNative srcWarpNative;
        HypNative dstWarpNative;
    }

    enum WarpRouteType {
        COLLATERAL_SYNTHETIC, // collateral <-> synthetic
        COLLATERAL_NATIVE, // collateral <-> native
        NATIVE_NATIVE // native <-> native

    }

    constructor() {
        TEST.EOA.deployer = makeAddr("DEPLOYER");
        TEST.EOA.feeSigner = makeAddr("FEE_SIGNER");
        TEST.EOA.alice = makeAddr("ALICE");
        TEST.EOA.bob = makeAddr("BOB");
        TEST.LZ.srcId = 1;
        TEST.LZ.dstId = 2;
    }

    function _initialize() internal {
        vm.createSelectFork(TEST.CONFIG.rpc);

        setUpEndpoints(2, LibraryType.UltraLightNode);

        vm.startPrank(TEST.EOA.deployer);
        deal(TEST.EOA.deployer, 100 ether);
        deal(TEST.CONFIG.weth, TEST.EOA.deployer, 100 ether);

        TEST.SRC = _deploy(address(endpoints[1]));
        TEST.DST = _deploy(address(endpoints[2]));

        _setupHyperlane();
        _connect();
        _liquify();

        vm.stopPrank();
    }

    function _deploy(address lzEndpoint) internal returns (Deployment memory deployment) {
        DecentBridgeDeployment memory bridge = _deployBridge(lzEndpoint);
        UTBDeployment memory utb = _deployUtb(bridge.decentEthRouter, bridge.decentBridgeExecutor);
        MockOft mockOft = _deployMockOft(lzEndpoint);

        deployment = Deployment({
            decentBridgeExecutor: bridge.decentBridgeExecutor,
            decentEthRouter: bridge.decentEthRouter,
            dcntEth: bridge.dcntEth,
            utb: utb.utb,
            utbExecutor: utb.utbExecutor,
            utbFeeManager: utb.utbFeeManager,
            uniSwapper: utb.uniSwapper,
            anySwapper: utb.anySwapper,
            decentBridgeAdapter: utb.decentBridgeAdapter,
            stargateBridgeAdapter: utb.stargateBridgeAdapter,
            hyperlaneBridgeAdapter: utb.hyperlaneBridgeAdapter,
            oftBridgeAdapter: utb.oftBridgeAdapter,
            yieldOftBridgeAdapter: utb.yieldOftBridgeAdapter,
            mockOft: mockOft
        });
    }

    function _connect() internal {
        _connectBridge(
            TEST.SRC.dcntEth, TEST.DST.dcntEth, TEST.SRC.decentEthRouter, TEST.DST.decentEthRouter, TEST.LZ.dstId
        );
        _connectBridge(
            TEST.DST.dcntEth, TEST.SRC.dcntEth, TEST.DST.decentEthRouter, TEST.SRC.decentEthRouter, TEST.LZ.srcId
        );
        _connectMockOft(TEST.SRC.mockOft, TEST.DST.mockOft, TEST.SRC.oftBridgeAdapter, TEST.LZ.dstId);
        _connectMockOft(TEST.DST.mockOft, TEST.SRC.mockOft, TEST.DST.oftBridgeAdapter, TEST.LZ.srcId);
        _connectUtb(
            TEST.SRC.decentBridgeAdapter,
            TEST.DST.decentBridgeAdapter,
            TEST.SRC.stargateBridgeAdapter,
            TEST.DST.stargateBridgeAdapter,
            TEST.SRC.hyperlaneBridgeAdapter,
            TEST.DST.hyperlaneBridgeAdapter,
            TEST.SRC.oftBridgeAdapter,
            TEST.DST.oftBridgeAdapter,
            TEST.SRC.yieldOftBridgeAdapter,
            TEST.DST.yieldOftBridgeAdapter,
            TEST.CONFIG.dstChainId,
            TEST.LZ.dstId
        );
        _connectUtb(
            TEST.DST.decentBridgeAdapter,
            TEST.SRC.decentBridgeAdapter,
            TEST.DST.stargateBridgeAdapter,
            TEST.SRC.stargateBridgeAdapter,
            TEST.DST.hyperlaneBridgeAdapter,
            TEST.SRC.hyperlaneBridgeAdapter,
            TEST.DST.oftBridgeAdapter,
            TEST.SRC.oftBridgeAdapter,
            TEST.DST.yieldOftBridgeAdapter,
            TEST.SRC.yieldOftBridgeAdapter,
            TEST.CONFIG.srcChainId,
            TEST.LZ.srcId
        );
    }

    function _liquify() internal {
        addLiquidity(TEST.SRC.decentEthRouter, 10 ether);
        addLiquidity(TEST.DST.decentEthRouter, 10 ether);
    }

    function _deployBridge(address lzEndpoint)
        internal
        returns (DecentBridgeDeployment memory decentBridgeDeployment)
    {
        DecentBridgeExecutor decentBridgeExecutor = new DecentBridgeExecutor(TEST.CONFIG.weth, TEST.CONFIG.isGasEth);
        DecentEthRouter decentEthRouter =
            new DecentEthRouter(payable(TEST.CONFIG.weth), TEST.CONFIG.isGasEth, address(decentBridgeExecutor));
        decentBridgeExecutor.setOperator(address(decentEthRouter));

        DcntEth dcntEth = new DcntEth(lzEndpoint);
        dcntEth.setRouter(address(decentEthRouter));
        decentEthRouter.registerDcntEth(address(dcntEth));

        decentBridgeDeployment = DecentBridgeDeployment({
            decentBridgeExecutor: decentBridgeExecutor,
            decentEthRouter: decentEthRouter,
            dcntEth: dcntEth
        });
    }

    function _deployMockOft(address lzEndpoint) internal returns (MockOft mockOft) {
        mockOft = new MockOft("Mock", "MOCK", lzEndpoint, msg.sender);
    }

    function _deployHyperlane() internal returns (MockMailbox localMailbox, MockMailbox remoteMailbox) {
        uint32 localDomain = uint32(TEST.CONFIG.srcChainId);
        uint32 remoteDomain = uint32(TEST.CONFIG.dstChainId);

        localMailbox = new MockMailbox(localDomain);
        remoteMailbox = new MockMailbox(remoteDomain);
        localMailbox.addRemoteMailbox(remoteDomain, remoteMailbox);
        remoteMailbox.addRemoteMailbox(localDomain, localMailbox);

        TestPostDispatchHook noopHook = new TestPostDispatchHook();
        TestInterchainGasPaymaster igp = new TestInterchainGasPaymaster();
        localMailbox.setDefaultHook(address(igp));
        localMailbox.setRequiredHook(address(noopHook));
        remoteMailbox.setDefaultHook(address(igp));
        remoteMailbox.setRequiredHook(address(noopHook));

        TEST.hyperlane.localMailbox = localMailbox;
        TEST.hyperlane.remoteMailbox = remoteMailbox;

        TEST.SRC.hyperlaneBridgeAdapter = new HyperlaneBridgeAdapter(DECIMALS, address(localMailbox));
        TEST.SRC.hyperlaneBridgeAdapter.setUtb(address(TEST.SRC.utb));
        TEST.SRC.utb.registerBridge(address(TEST.SRC.hyperlaneBridgeAdapter));

        TEST.DST.hyperlaneBridgeAdapter = new HyperlaneBridgeAdapter(DECIMALS, address(remoteMailbox));
        TEST.DST.hyperlaneBridgeAdapter.setUtb(address(TEST.DST.utb));
        TEST.DST.utb.registerBridge(address(TEST.DST.hyperlaneBridgeAdapter));
    }

    function _setupHyperlane() internal {
        string memory NAME = "mUSDT";
        string memory SYMBOL = "mUSDT";

        MockErc20 primaryToken = new MockErc20(NAME, SYMBOL);
        TEST.hyperlane.primaryToken = IERC20(address(primaryToken));
        MockErc20 weth = new MockErc20("WETH", "WETH");
        TEST.hyperlane.weth = IERC20(address(weth));
        weth.mint(TEST.EOA.alice, 100 ether);

        (MockMailbox localMailbox, MockMailbox remoteMailbox) = _deployHyperlane();

        // collateral <-> warpSynthetic
        HypERC20 warpSynthetic = new HypERC20(DECIMALS, address(remoteMailbox));
        HypERC20Collateral warpCollateral = new HypERC20Collateral(address(primaryToken), address(localMailbox));
        warpCollateral.initialize(
            address(localMailbox.defaultHook()), address(localMailbox.defaultIsm()), TEST.EOA.deployer
        );

        // collateral <-> native
        HypERC20Collateral nativeCollateral =
            new HypERC20Collateral(address(TEST.hyperlane.weth), address(localMailbox));
        nativeCollateral.initialize(
            address(localMailbox.defaultHook()), address(localMailbox.defaultIsm()), TEST.EOA.deployer
        );
        HypNative native = new HypNative(address(remoteMailbox));
        native.initialize(address(remoteMailbox.defaultHook()), address(remoteMailbox.defaultIsm()), TEST.EOA.deployer);

        // native <-> native
        HypNative srcNative = new HypNative(address(localMailbox));
        srcNative.initialize(address(localMailbox.defaultHook()), address(localMailbox.defaultIsm()), TEST.EOA.deployer);

        HypNative dstNative = new HypNative(address(remoteMailbox));
        dstNative.initialize(
            address(remoteMailbox.defaultHook()), address(remoteMailbox.defaultIsm()), TEST.EOA.deployer
        );

        TEST.hyperlane.warpSynthetic = warpSynthetic;
        TEST.hyperlane.warpCollateral = warpCollateral;
        TEST.hyperlane.nativeCollateral = nativeCollateral;
        TEST.hyperlane.warpNative = native;
        TEST.hyperlane.srcWarpNative = srcNative;
        TEST.hyperlane.dstWarpNative = dstNative;
    }

    function _deployUtb(DecentEthRouter decentEthRouter, DecentBridgeExecutor decentBridgeExecutor)
        internal
        returns (UTBDeployment memory utbDeployment)
    {
        UTB utb = new UTB();
        utb.setWrapped(payable(TEST.CONFIG.weth));

        utbDeployment = UTBDeployment({
            utb: utb,
            utbExecutor: _deployUtbExecutor(utb),
            utbFeeManager: _deployUtbFeeManager(utb),
            uniSwapper: _deployUniSwapper(utb),
            anySwapper: _deployAnySwapper(utb),
            decentBridgeAdapter: _deployDecentBridgeAdapter(utb, decentEthRouter, decentBridgeExecutor),
            stargateBridgeAdapter: _deployStargateBridgeAdapter(utb),
            hyperlaneBridgeAdapter: _deployHyperlaneBridgeAdapter(utb),
            oftBridgeAdapter: _deployOftBridgeAdapter(utb),
            yieldOftBridgeAdapter: _deployYieldOftBridgeAdapter(utb)
        });
    }

    function _deployUtbExecutor(UTB utb) internal returns (UTBExecutor utbExecutor) {
        utbExecutor = new UTBExecutor();
        utbExecutor.setOperator(address(utb));
        utb.setExecutor(address(utbExecutor));
    }

    function _deployUtbFeeManager(UTB utb) internal returns (UTBFeeManager utbFeeManager) {
        utbFeeManager = new UTBFeeManager(TEST.EOA.feeSigner);
        utb.setFeeManager(payable(address(utbFeeManager)));
    }

    function _deployUniSwapper(UTB utb) internal returns (UniSwapper uniSwapper) {
        uniSwapper = new UniSwapper();
        uniSwapper.setWrapped(payable(TEST.CONFIG.weth));
        uniSwapper.setRouter(TEST.CONFIG.uniswap);
        uniSwapper.setUtb(address(utb));
        utb.registerSwapper(address(uniSwapper));
    }

    function _deployAnySwapper(UTB utb) internal returns (AnySwapper anySwapper) {
        anySwapper = new AnySwapper();
        anySwapper.setWrapped(payable(TEST.CONFIG.weth));
        anySwapper.setUtb(address(utb));
        utb.registerSwapper(address(anySwapper));
    }

    function _deployDecentBridgeAdapter(
        UTB utb,
        DecentEthRouter decentEthRouter,
        DecentBridgeExecutor decentBridgeExecutor
    ) internal returns (DecentBridgeAdapter decentBridgeAdapter) {
        address bridgeToken = TEST.CONFIG.isGasEth ? address(0) : TEST.CONFIG.weth;

        decentBridgeAdapter = new DecentBridgeAdapter(TEST.CONFIG.isGasEth, DECIMALS, bridgeToken);
        decentBridgeAdapter.setUtb(address(utb));
        decentBridgeAdapter.setRouter(address(decentEthRouter));
        decentBridgeAdapter.setBridgeExecutor(address(decentBridgeExecutor));
        utb.registerBridge(address(decentBridgeAdapter));
    }

    function _deployStargateBridgeAdapter(UTB utb) internal returns (StargateBridgeAdapter stargateBridgeAdapter) {
        stargateBridgeAdapter = new StargateBridgeAdapter(DECIMALS, TEST.CONFIG.stargateFactory);
        stargateBridgeAdapter.setUtb(address(utb));
        stargateBridgeAdapter.setStargateComposer(TEST.CONFIG.stargateComposer);
        stargateBridgeAdapter.setStargateEth(TEST.CONFIG.stargateEth);
        stargateBridgeAdapter.setBridgeExecutor(TEST.CONFIG.stargateComposer);
        utb.registerBridge(address(stargateBridgeAdapter));
    }

    function _deployHyperlaneBridgeAdapter(UTB /*utb*/ )
        internal
        pure
        returns (HyperlaneBridgeAdapter hyperlaneBridgeAdapter)
    {
        // NOTE: dummy address which gets overridden by _deployHyperlane()
        hyperlaneBridgeAdapter = HyperlaneBridgeAdapter(payable(address(0)));
    }

    function _deployOftBridgeAdapter(UTB utb) internal returns (OftBridgeAdapter oftBridgeAdapter) {
        oftBridgeAdapter = new OftBridgeAdapter(DECIMALS);
        oftBridgeAdapter.setUtb(address(utb));
        utb.registerBridge(address(oftBridgeAdapter));
    }

    function _deployYieldOftBridgeAdapter(UTB utb) internal returns (YieldOftBridgeAdapter yieldOftBridgeAdapter) {
        yieldOftBridgeAdapter = new YieldOftBridgeAdapter(DECIMALS);
        yieldOftBridgeAdapter.setUtb(address(utb));
        utb.registerBridge(address(yieldOftBridgeAdapter));
    }

    function _connectBridge(
        DcntEth srcDcntEth,
        DcntEth dstDcntEth,
        DecentEthRouter srcDecentEthRouter,
        DecentEthRouter dstDecentEthRouter,
        uint32 _dstLzId
    ) internal {
        srcDecentEthRouter.addDestinationBridge(_dstLzId, address(dstDecentEthRouter));
        srcDcntEth.setPeer(_dstLzId, addressToBytes32(address(dstDcntEth)));
    }

    function _connectMockOft(
        MockOft srcMockOft,
        MockOft dstMockOft,
        OftBridgeAdapter srcOftBridgeAdapter,
        uint32 _dstLzId
    ) internal {
        srcOftBridgeAdapter.permissionOft(address(srcMockOft), address(srcMockOft));
        srcMockOft.setPeer(_dstLzId, addressToBytes32(address(dstMockOft)));
    }

    function _connectUtb(
        DecentBridgeAdapter srcDecentBridgeAdapter,
        DecentBridgeAdapter dstDecentBridgeAdapter,
        StargateBridgeAdapter srcStargateBridgeAdapter,
        StargateBridgeAdapter dstStargateBridgeAdapter,
        HyperlaneBridgeAdapter srcHyperlaneBridgeAdapter,
        HyperlaneBridgeAdapter dstHyperlaneBridgeAdapter,
        OftBridgeAdapter srcOftBridgeAdapter,
        OftBridgeAdapter dstOftBridgeAdapter,
        YieldOftBridgeAdapter srcYieldOftBridgeAdapter,
        YieldOftBridgeAdapter dstYieldOftBridgeAdapter,
        uint256 _dstChainId,
        uint32 _dstLzId
    ) internal {
        srcDecentBridgeAdapter.registerRemoteBridgeAdapter(
            _dstChainId, _dstLzId, DECIMALS, address(dstDecentBridgeAdapter)
        );
        srcStargateBridgeAdapter.registerRemoteBridgeAdapter(
            _dstChainId, uint16(_dstLzId), DECIMALS, address(dstStargateBridgeAdapter)
        );
        srcHyperlaneBridgeAdapter.registerRemoteBridgeAdapter(
            TEST.CONFIG.dstChainId, DECIMALS, address(dstHyperlaneBridgeAdapter)
        );
        dstHyperlaneBridgeAdapter.registerRemoteBridgeAdapter(
            TEST.CONFIG.srcChainId, DECIMALS, address(srcHyperlaneBridgeAdapter)
        );
        srcOftBridgeAdapter.registerRemoteBridgeAdapter(_dstChainId, _dstLzId, DECIMALS, address(dstOftBridgeAdapter));
        srcYieldOftBridgeAdapter.registerRemoteBridgeAdapter(
            _dstChainId, _dstLzId, DECIMALS, address(dstYieldOftBridgeAdapter)
        );
    }

    function _connectWarpRoute(WarpRouteType routeType) internal {
        vm.startPrank(TEST.EOA.deployer);

        if (routeType == WarpRouteType.COLLATERAL_SYNTHETIC) {
            _setupWarpRoute(
                TEST.hyperlane.warpCollateral,
                TEST.hyperlane.warpSynthetic,
                address(TEST.hyperlane.primaryToken),
                address(TEST.hyperlane.warpSynthetic)
            );
        }

        if (routeType == WarpRouteType.COLLATERAL_NATIVE) {
            _setupWarpRoute(
                TEST.hyperlane.nativeCollateral, TEST.hyperlane.warpNative, address(TEST.hyperlane.weth), address(0)
            );
        }

        if (routeType == WarpRouteType.NATIVE_NATIVE) {
            _setupWarpRoute(TEST.hyperlane.srcWarpNative, TEST.hyperlane.dstWarpNative, address(0), address(0));
        }

        vm.stopPrank();
    }

    function _setupWarpRoute(TokenRouter srcRouter, TokenRouter dstRouter, address srcToken, address dstToken)
        internal
    {
        srcRouter.enrollRemoteRouter(uint32(TEST.CONFIG.dstChainId), address(dstRouter).addressToBytes32());
        dstRouter.enrollRemoteRouter(uint32(TEST.CONFIG.srcChainId), address(srcRouter).addressToBytes32());

        TEST.SRC.hyperlaneBridgeAdapter.addWarpRoute(
            uint32(TEST.CONFIG.dstChainId), address(srcRouter), srcToken, dstToken
        );
        TEST.DST.hyperlaneBridgeAdapter.addWarpRoute(
            uint32(TEST.CONFIG.srcChainId), address(dstRouter), dstToken, srcToken
        );
    }

    function addLiquidity(DecentEthRouter decentEthRouter, uint256 amount) public {
        if (TEST.CONFIG.isGasEth) {
            decentEthRouter.addLiquidityEth{value: amount}();
        } else {
            IWETH(payable(TEST.CONFIG.weth)).approve(address(decentEthRouter), amount);
            decentEthRouter.addLiquidityWeth(amount);
        }
    }

    function getSignature(bytes memory inputBytes) public returns (bytes memory signature) {
        string memory BANNER = "\x19Ethereum Signed Message:\n32";

        bytes32 hash = keccak256(abi.encodePacked(BANNER, keccak256(inputBytes)));

        ( /*address addr*/ , uint256 privateKey) = makeAddrAndKey("FEE_SIGNER");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);

        signature = abi.encodePacked(r, s, v);
    }
}
