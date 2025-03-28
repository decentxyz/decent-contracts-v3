// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {VeryCoolCat} from "./helpers/VeryCoolCat.sol";
import {HyperlaneBridgeAdapter} from "../src/bridge_adapters/HyperlaneBridgeAdapter.sol";
import {EthereumFixture} from "./common/EthereumFixture.sol";
import {SwapInstructions, BridgeInstructions, SwapAndExecuteInstructions, FeeData, Fee} from "../src/UTB.sol";
import {SwapParams, SwapDirection} from "../src/CommonTypes.sol";
import {MockErc20} from "./helpers/MockErc20.sol";
import {IMailbox} from "@hyperlane-xyz/contracts/interfaces/IMailbox.sol";
import {TypeCasts} from "@hyperlane-xyz/contracts/libs/TypeCasts.sol";
import {TestInterchainGasPaymaster} from "@hyperlane-xyz/contracts/test/TestInterchainGasPaymaster.sol";

contract HyperlaneBridgeAdapterTest is Test, EthereumFixture {
    using TypeCasts for address;
    using TypeCasts for bytes32;

    VeryCoolCat cat;
    BridgeInstructions bridgeInstructions;
    address payable refund;
    address feeRecipient = address(0x1CE0FFEE);
    uint64 GAS_TO_MINT = 500_000;
    uint256 CALL_GAS_LIMIT = 250_000;
    bytes32 public constant TRANSACTION_ID = keccak256("TRANSACTION_ID");

    function setUp() public {
        cat = new VeryCoolCat();
        refund = payable(TEST.EOA.alice);
        deal(TEST.EOA.alice, 1000 ether);

        cat.setUsdt(address(TEST.hyperlane.warpSynthetic));
    }

    function test_bridgeAndExecute_usdtToSynthetic() public {
        _connectWarpRoute(WarpRouteType.COLLATERAL_SYNTHETIC);

        uint256 amount = cat.usdtPrice();

        // start with alice having some primaryToken and approve it for UTB
        MockErc20(address(TEST.hyperlane.primaryToken)).mint(address(TEST.EOA.alice), amount);
        vm.prank(TEST.EOA.alice);
        TEST.hyperlane.primaryToken.approve(address(TEST.SRC.utb), amount);

        bridgeInstructions = _getBridgeInstructions(
            address(TEST.hyperlane.primaryToken),
            address(TEST.hyperlane.warpSynthetic),
            address(TEST.hyperlane.warpCollateral),
            amount,
            cat.mintWithUsdt.selector,
            false
        );

        bytes memory msgBody = _getMessageBody(bridgeInstructions);
        FeeData memory feeData = _getFeeData(address(TEST.hyperlane.warpCollateral), false, msgBody);

        // bridge
        vm.prank(TEST.EOA.alice);
        TEST.SRC.utb.bridgeAndExecute{value: feeData.bridgeFee}(
            bridgeInstructions, feeData, getSignature(abi.encode(bridgeInstructions, feeData))
        );

        TEST.hyperlane.remoteMailbox.processNextInboundMessage(); // token transfer
        TEST.hyperlane.remoteMailbox.processNextInboundMessage(); // account call

        assertEq(cat.balanceOf(TEST.EOA.alice), 1);
        assertEq(TEST.hyperlane.warpSynthetic.balanceOf(address(TEST.DST.hyperlaneBridgeAdapter)), 0);
    }

    function test_bridgeAndExecute_syntheticToUsdt() public {
        _connectWarpRoute(WarpRouteType.COLLATERAL_SYNTHETIC);

        cat.setUsdt(address(TEST.hyperlane.primaryToken));

        uint256 amount = cat.usdtPrice();

        // start with alice having some synthetic tokens and approve it for UTB
        deal(address(TEST.hyperlane.warpSynthetic), TEST.EOA.alice, amount);
        vm.prank(TEST.EOA.alice);
        TEST.hyperlane.warpSynthetic.approve(address(TEST.DST.utb), amount);

        bridgeInstructions = _getBridgeInstructions(
            address(TEST.hyperlane.warpSynthetic),
            address(TEST.hyperlane.primaryToken),
            address(TEST.hyperlane.warpSynthetic),
            amount,
            cat.mintWithUsdt.selector,
            true
        );

        bytes memory msgBody = _getMessageBody(bridgeInstructions);
        FeeData memory feeData = _getFeeData(address(TEST.hyperlane.warpSynthetic), true, msgBody);

        // bridge
        vm.prank(TEST.EOA.alice);
        TEST.DST.utb.bridgeAndExecute{value: feeData.bridgeFee}(
            bridgeInstructions, feeData, getSignature(abi.encode(bridgeInstructions, feeData))
        );

        MockErc20(address(TEST.hyperlane.primaryToken)).mint(address(TEST.hyperlane.warpCollateral), amount);
        TEST.hyperlane.localMailbox.processNextInboundMessage(); // token transfer
        TEST.hyperlane.localMailbox.processNextInboundMessage(); // account call

        assertEq(cat.balanceOf(TEST.EOA.alice), 1);
        assertEq(TEST.hyperlane.primaryToken.balanceOf(address(TEST.DST.hyperlaneBridgeAdapter)), 0);
    }

    function test_handleTransfer_revertsWhen_unauthorized() public {
        vm.prank(address(TEST.EOA.alice));

        vm.expectRevert(HyperlaneBridgeAdapter.OnlyPermissionedMailbox.selector);
        TEST.DST.hyperlaneBridgeAdapter.handle(
            uint32(TEST.CONFIG.srcChainId), address(TEST.SRC.hyperlaneBridgeAdapter).addressToBytes32(), ""
        );

        vm.prank(address(TEST.hyperlane.remoteMailbox));
        vm.expectRevert(HyperlaneBridgeAdapter.InvalidSender.selector);
        TEST.DST.hyperlaneBridgeAdapter.handle(uint32(TEST.CONFIG.srcChainId), address(0).addressToBytes32(), "");
    }

    function test_bridge_refundOverpayment() public {
        _connectWarpRoute(WarpRouteType.COLLATERAL_SYNTHETIC);

        uint256 amount = cat.usdtPrice();
        uint256 excess = 1000000;

        uint256 balBefore = address(TEST.SRC.hyperlaneBridgeAdapter).balance;

        MockErc20(address(TEST.hyperlane.primaryToken)).mint(address(TEST.EOA.alice), amount);
        vm.prank(TEST.EOA.alice);
        TEST.hyperlane.primaryToken.approve(address(TEST.SRC.utb), amount);

        bridgeInstructions = _getBridgeInstructions(
            address(TEST.hyperlane.primaryToken),
            address(TEST.hyperlane.warpSynthetic),
            address(TEST.hyperlane.warpCollateral),
            amount,
            cat.mintWithUsdt.selector,
            false
        );

        bytes memory msgBody = _getMessageBody(bridgeInstructions);
        FeeData memory feeData = _getFeeData(address(TEST.hyperlane.warpCollateral), false, msgBody);

        uint256 initialAliceBalance = TEST.EOA.alice.balance;

        vm.prank(TEST.EOA.alice);
        TEST.SRC.utb.bridgeAndExecute{value: feeData.bridgeFee + excess}(
            bridgeInstructions, feeData, getSignature(abi.encode(bridgeInstructions, feeData))
        );

        vm.assertEq(TEST.EOA.alice.balance, initialAliceBalance - feeData.bridgeFee);
        vm.assertEq(address(TEST.SRC.utb).balance, 0);
        vm.assertEq(address(TEST.SRC.hyperlaneBridgeAdapter).balance, balBefore);
    }

    function test_handle_refundOverpayment() public {
        _connectWarpRoute(WarpRouteType.COLLATERAL_SYNTHETIC);

        uint256 amount = cat.usdtPrice();
        bridgeInstructions = _getBridgeInstructions(
            address(TEST.hyperlane.primaryToken),
            address(TEST.hyperlane.warpSynthetic),
            address(TEST.hyperlane.warpCollateral),
            amount * 2,
            cat.mintWithUsdt.selector,
            false
        );

        vm.startPrank(address(TEST.hyperlane.remoteMailbox));
        TEST.hyperlane.warpSynthetic.handle(
            uint32(TEST.CONFIG.srcChainId),
            address(TEST.hyperlane.warpCollateral).addressToBytes32(),
            abi.encodePacked(address(TEST.DST.hyperlaneBridgeAdapter).addressToBytes32(), amount * 2)
        );

        bytes memory payload = abi.encode(
            bridgeInstructions.postBridge,
            bridgeInstructions.target,
            bridgeInstructions.paymentOperator,
            bridgeInstructions.payload,
            bridgeInstructions.refund,
            bridgeInstructions.txId
        );
        TEST.DST.hyperlaneBridgeAdapter.handle(
            uint32(TEST.CONFIG.srcChainId), address(TEST.SRC.hyperlaneBridgeAdapter).addressToBytes32(), payload
        );

        vm.assertEq(TEST.hyperlane.warpSynthetic.balanceOf(address(TEST.DST.hyperlaneBridgeAdapter)), 0);
        vm.assertEq(TEST.hyperlane.warpSynthetic.balanceOf(TEST.EOA.alice), amount);
        vm.assertEq(cat.balanceOf(TEST.EOA.alice), 1);
    }

    // encoded function is mintWithUsdc and wrapped asset is usdt (warpSynthetic)
    function test_handleTransfer_executionFailure() public {
        _connectWarpRoute(WarpRouteType.COLLATERAL_SYNTHETIC);

        uint256 amount = cat.usdtPrice();
        bridgeInstructions = _getBridgeInstructions(
            address(TEST.hyperlane.primaryToken),
            address(TEST.hyperlane.warpSynthetic),
            address(TEST.hyperlane.warpCollateral),
            amount,
            cat.mintWithUsdc.selector,
            false
        );

        vm.startPrank(address(TEST.hyperlane.remoteMailbox));
        TEST.hyperlane.warpSynthetic.handle(
            uint32(TEST.CONFIG.srcChainId),
            address(TEST.hyperlane.warpCollateral).addressToBytes32(),
            abi.encodePacked(address(TEST.DST.hyperlaneBridgeAdapter).addressToBytes32(), amount)
        );

        bytes memory payload = abi.encode(
            bridgeInstructions.postBridge,
            bridgeInstructions.target,
            bridgeInstructions.paymentOperator,
            bridgeInstructions.payload,
            bridgeInstructions.refund,
            bridgeInstructions.txId
        );
        TEST.DST.hyperlaneBridgeAdapter.handle(
            uint32(TEST.CONFIG.srcChainId), address(TEST.SRC.hyperlaneBridgeAdapter).addressToBytes32(), payload
        );

        vm.assertEq(TEST.hyperlane.warpSynthetic.balanceOf(address(TEST.DST.hyperlaneBridgeAdapter)), 0);
        vm.assertEq(TEST.hyperlane.warpSynthetic.balanceOf(TEST.EOA.alice), amount);
        vm.assertEq(cat.balanceOf(TEST.EOA.alice), 0);
    }

    function test_bridgeAndExecute_wethToNative() public {
        _connectWarpRoute(WarpRouteType.COLLATERAL_NATIVE);

        uint256 amount = cat.ethPrice();

        MockErc20(address(TEST.hyperlane.primaryToken)).mint(address(TEST.EOA.alice), amount);
        vm.prank(TEST.EOA.alice);
        IERC20(TEST.hyperlane.weth).approve(address(TEST.SRC.utb), amount);

        bridgeInstructions =
            _getBridgeInstructions(
                address(TEST.hyperlane.weth),
                address(0),
                address(TEST.hyperlane.nativeCollateral),
                amount,
                cat.mintWithEth.selector,
                false
            );

        bytes memory msgBody = _getMessageBody(bridgeInstructions);
        FeeData memory feeData = _getFeeData(address(TEST.hyperlane.nativeCollateral), false, msgBody);

        vm.prank(TEST.EOA.alice);
        TEST.SRC.utb.bridgeAndExecute{value: feeData.bridgeFee + amount}(
            bridgeInstructions, feeData, getSignature(abi.encode(bridgeInstructions, feeData))
        );

        vm.deal(address(TEST.hyperlane.warpNative), amount);
        TEST.hyperlane.remoteMailbox.processNextInboundMessage(); // token transfer
        TEST.hyperlane.remoteMailbox.processNextInboundMessage(); // account call

        assertEq(cat.balanceOf(TEST.EOA.alice), 1);
        assertEq(address(TEST.DST.hyperlaneBridgeAdapter).balance, 0);
    }

    function test_bridgeAndExecute_nativeToWeth() public {
        _connectWarpRoute(WarpRouteType.COLLATERAL_NATIVE);

        uint256 amount = cat.wethPrice();
        cat.setWeth(address(TEST.hyperlane.weth));

        bridgeInstructions =
            _getBridgeInstructions(
                address(0),
                address(TEST.hyperlane.weth),
                address(TEST.hyperlane.warpNative),
                amount,
                cat.mintWithWeth.selector,
                true
            );

        // Fund Alice with enough ETH for the NFT price and bridge fee
        bytes memory msgBody = _getMessageBody(bridgeInstructions);
        FeeData memory feeData = _getFeeData(address(TEST.hyperlane.warpNative), true, msgBody);
        vm.deal(TEST.EOA.alice, amount + feeData.bridgeFee);

        // Bridge native ETH from source chain
        vm.prank(TEST.EOA.alice);
        TEST.DST.utb.bridgeAndExecute{value: feeData.bridgeFee + amount}(
            bridgeInstructions, feeData, getSignature(abi.encode(bridgeInstructions, feeData))
        );

        // Fund destination chain and simulate message delivery
        MockErc20(address(TEST.hyperlane.weth)).mint(address(TEST.hyperlane.nativeCollateral), amount);
        TEST.hyperlane.localMailbox.processNextInboundMessage(); // token transfer
        TEST.hyperlane.localMailbox.processNextInboundMessage(); // account call

        // Verify NFT was minted to Alice and no WETH remains in adapter
        assertEq(cat.balanceOf(TEST.EOA.alice), 1);
        assertEq(TEST.hyperlane.weth.balanceOf(address(TEST.DST.hyperlaneBridgeAdapter)), 0);
    }

    function test_bridgeAndExectute_nativeToNative() public {
        _connectWarpRoute(WarpRouteType.NATIVE_NATIVE);

        uint256 amount = cat.ethPrice();

        bridgeInstructions = _getBridgeInstructions(
            address(0),
            address(0),
            address(TEST.hyperlane.srcWarpNative),
            amount,
            cat.mintWithEth.selector,
            false);

        bytes memory msgBody = _getMessageBody(bridgeInstructions);
        FeeData memory feeData = _getFeeData(address(TEST.hyperlane.srcWarpNative), false, msgBody);

        // Fund Alice with enough for both the NFT price and bridge fee
        vm.deal(TEST.EOA.alice, amount + feeData.bridgeFee);

        // Bridge ETH from source chain
        vm.prank(TEST.EOA.alice);
        TEST.SRC.utb.bridgeAndExecute{value: feeData.bridgeFee + amount}(
            bridgeInstructions, feeData, getSignature(abi.encode(bridgeInstructions, feeData))
        );

        // Fund destination chain and simulate message delivery
        vm.deal(address(TEST.hyperlane.srcWarpNative), amount);
        vm.deal(address(TEST.hyperlane.dstWarpNative), amount);
        TEST.hyperlane.remoteMailbox.processNextInboundMessage();
        TEST.hyperlane.remoteMailbox.processNextInboundMessage();

        // Verify NFT was minted to Alice
        assertEq(cat.balanceOf(TEST.EOA.alice), 1);
        assertEq(address(TEST.DST.hyperlaneBridgeAdapter).balance, 0);
    }

    function test_bridgeAndExectute_nativeToNative_reverse() public {
        _connectWarpRoute(WarpRouteType.NATIVE_NATIVE);

        uint256 amount = cat.ethPrice();

        bridgeInstructions = _getBridgeInstructions(
            address(0),
            address(0),
            address(TEST.hyperlane.dstWarpNative),
            amount,
            cat.mintWithEth.selector,
            true
        );

        bytes memory msgBody = _getMessageBody(bridgeInstructions);
        FeeData memory feeData = _getFeeData(address(TEST.hyperlane.dstWarpNative), true, msgBody);

        // Fund Alice with enough for both the NFT price and bridge fee
        vm.deal(TEST.EOA.alice, amount + feeData.bridgeFee);

        // Bridge ETH from source chain
        vm.prank(TEST.EOA.alice);
        TEST.DST.utb.bridgeAndExecute{value: feeData.bridgeFee + amount}(
            bridgeInstructions, feeData, getSignature(abi.encode(bridgeInstructions, feeData))
        );

        // Fund destination chain and simulate message delivery
        vm.deal(address(TEST.hyperlane.srcWarpNative), amount);
        vm.deal(address(TEST.hyperlane.dstWarpNative), amount);
        TEST.hyperlane.localMailbox.processNextInboundMessage();
        TEST.hyperlane.localMailbox.processNextInboundMessage();

        // Verify NFT was minted to Alice
        assertEq(cat.balanceOf(TEST.EOA.alice), 1);
        assertEq(address(TEST.DST.hyperlaneBridgeAdapter).balance, 0);
    }

    function testFuzz_customGasLimit(uint128 callGasLimit) public {
        _connectWarpRoute(WarpRouteType.NATIVE_NATIVE);
        TestInterchainGasPaymaster igp = TestInterchainGasPaymaster(address(TEST.hyperlane.localMailbox.defaultHook()));

        uint256 baseline = TEST.SRC.hyperlaneBridgeAdapter.quoteGasPayment(TEST.CONFIG.dstChainId, address(TEST.hyperlane.srcWarpNative), "", 0);
        uint256 customQuote =
            TEST.SRC.hyperlaneBridgeAdapter.quoteGasPayment(TEST.CONFIG.dstChainId, address(TEST.hyperlane.srcWarpNative), "", callGasLimit);

        assertEq(customQuote, baseline + callGasLimit * igp.gasPrice());
    }

    function _getFeeData(address router, bool reverse, bytes memory msgBody) internal view returns (FeeData memory) {
        uint256 hyperlaneFees = reverse
            ? TEST.DST.hyperlaneBridgeAdapter.quoteGasPayment(TEST.CONFIG.srcChainId, router, msgBody, CALL_GAS_LIMIT)
            : TEST.SRC.hyperlaneBridgeAdapter.quoteGasPayment(TEST.CONFIG.dstChainId, router, msgBody, CALL_GAS_LIMIT);

        FeeData memory feeData = FeeData({
            appId: bytes4(0),
            affiliateId: bytes4(0),
            bridgeFee: hyperlaneFees,
            deadline: block.timestamp,
            chainId: block.chainid,
            appFees: new Fee[](0)
        });

        return feeData;
    }

    function _getBridgeInstructions(
        address tokenIn,
        address tokenOut,
        address router,
        uint256 amount,
        bytes4 dstCallSelector,
        bool reverse
    ) internal view returns (BridgeInstructions memory) {
        return BridgeInstructions({
            preBridge: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: tokenIn,
                    amountIn: amount,
                    tokenOut: tokenIn,
                    amountOut: amount,
                    dustOut: 0,
                    direction: SwapDirection.EXACT_OUT,
                    refund: refund,
                    additionalArgs: ""
                })
            }),
            postBridge: SwapInstructions({
                swapperId: TEST.DST.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: tokenOut,
                    amountIn: amount,
                    tokenOut: tokenOut,
                    amountOut: amount,
                    dustOut: 0,
                    direction: SwapDirection.EXACT_OUT,
                    refund: refund,
                    additionalArgs: ""
                })
            }),
            bridgeId: TEST.SRC.hyperlaneBridgeAdapter.ID(),
            dstChainId: reverse ? TEST.CONFIG.srcChainId : TEST.CONFIG.dstChainId,
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            txId: TRANSACTION_ID,
            payload: abi.encodeWithSelector(dstCallSelector, (TEST.EOA.alice)),
            additionalArgs: abi.encode(tokenIn, CALL_GAS_LIMIT, router)
        });
    }

    function _getMessageBody(BridgeInstructions memory _bridgeInstructions) internal pure returns (bytes memory) {
        return abi.encode(
            _bridgeInstructions.postBridge,
            _bridgeInstructions.target,
            _bridgeInstructions.paymentOperator,
            _bridgeInstructions.payload,
            _bridgeInstructions.refund,
            _bridgeInstructions.txId
        );
    }
}
