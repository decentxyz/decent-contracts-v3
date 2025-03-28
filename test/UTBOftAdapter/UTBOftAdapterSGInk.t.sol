// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// forge contracts
import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

// test fixture
import {InkFixture} from "../common/InkFixture.sol";
import {UTBOftAdapterSetup} from "./UTBOftAdapterSetup.sol";

// utb contracts
import {SwapInstructions, BridgeInstructions, FeeData, Fee} from "../../src/UTB.sol";
import {SwapParams, SwapDirection} from "../../src/CommonTypes.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {OftBridgeAdapter} from "../../src/bridge_adapters/OftBridgeAdapter.sol";

// layerzero contracts
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {IOFT, OFTReceipt, SendParam} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

// openzep contracts
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract UTBOftAdapterStargate is UTBOftAdapterSetup, InkFixture {
    using OptionsBuilder for bytes;

    function test_bridgeAndExecute_oft_send() public {
        uint256 amount = 100e6;

        address usdc = 0xF1815bd50389c46847f0Bda824eC8da914045D14;
        address lzOftAdapter = 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590;

        vm.startPrank(TEST.EOA.deployer);
        TEST.SRC.oftBridgeAdapter.registerRemoteBridgeAdapter(
            TEST.CONFIG.dstChainId, TEST.CONFIG.dstLzV2Id, 18, address(TEST.DST.oftBridgeAdapter)
        );
        TEST.SRC.oftBridgeAdapter.permissionOft(usdc, lzOftAdapter);
        vm.stopPrank();

        deal(usdc, TEST.EOA.alice, amount);

        bridgeInstructions = BridgeInstructions({
            preBridge: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: usdc,
                    amountIn: amount,
                    tokenOut: usdc,
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
                    tokenIn: usdc,
                    amountIn: amount,
                    tokenOut: usdc,
                    amountOut: amount,
                    dustOut: 0,
                    direction: SwapDirection.EXACT_OUT,
                    refund: refund,
                    additionalArgs: ""
                })
            }),
            bridgeId: TEST.SRC.oftBridgeAdapter.ID(),
            dstChainId: TEST.CONFIG.dstChainId,
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            payload: abi.encodeCall(cat.mintWithErc20, (TEST.EOA.alice, usdc, amount)),
            additionalArgs: abi.encode(usdc, GAS_TO_MINT, lzOftAdapter),
            txId: TRANSACTION_ID
        });

        IBridgeAdapter.BridgeCall memory bridgeCall = IBridgeAdapter.BridgeCall({
            amount: amount,
            postBridge: bridgeInstructions.postBridge,
            dstChainId: TEST.CONFIG.dstChainId,
            target: bridgeInstructions.target,
            paymentOperator: bridgeInstructions.paymentOperator,
            payload: bridgeInstructions.payload,
            additionalArgs: bridgeInstructions.additionalArgs,
            refund: bridgeInstructions.refund,
            txId: TRANSACTION_ID
        });

        (uint lzNativeFee, /*uint lzZroFee*/) = TEST.SRC.oftBridgeAdapter.estimateFees(bridgeCall);

        (/*uint256 amountSentLD*/, uint256 amountReceivedLD) = TEST.SRC.oftBridgeAdapter.estimateOft(bridgeCall);

        FeeData memory feeData = FeeData({
            appId: bytes4(0),
            affiliateId: bytes4(0),
            bridgeFee: lzNativeFee,
            deadline: block.timestamp,
            chainId: block.chainid,
            appFees: new Fee[](1)
        });

        feeData.appFees[0] = Fee({
            recipient: feeRecipient,
            token: address(0),
            amount: nativeFee
        });

        vm.prank(TEST.EOA.alice);
        IERC20(usdc).approve(address(TEST.SRC.utb), amount);

        vm.expectEmit(false, true, false, true);
        emit IOFT.OFTSent("", TEST.CONFIG.dstLzV2Id, address(TEST.SRC.oftBridgeAdapter), amount, amountReceivedLD);

        vm.prank(TEST.EOA.alice);
        TEST.SRC.utb.bridgeAndExecute{value: nativeFee + lzNativeFee}(
            bridgeInstructions,
            feeData,
            getSignature(abi.encode(bridgeInstructions, feeData))
        );
    }

    function test_bridgeAndExecute_oft_receive() public {
        uint256 amount = 100e6;

        address usdc = 0xF1815bd50389c46847f0Bda824eC8da914045D14;
        address lzOftAdapter = 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590;

        OftBridgeAdapter oftBridgeAdapter = TEST.SRC.oftBridgeAdapter;
        address lzEndpoint = 0xca29f3A6f966Cb2fc0dE625F8f325c0C46dbE958;

        vm.startPrank(TEST.EOA.deployer);
        oftBridgeAdapter.permissionOft(usdc, lzOftAdapter);
        vm.stopPrank();

        bytes memory composeMsg = abi.encode(
            SwapInstructions({
                swapperId: TEST.DST.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: usdc,
                    amountIn: amount,
                    tokenOut: usdc,
                    amountOut: amount,
                    dustOut: 0,
                    direction: SwapDirection.EXACT_OUT,
                    refund: refund,
                    additionalArgs: ""
                })
            }),
            TEST.EOA.alice,
            TEST.EOA.alice,
            "",
            TEST.EOA.alice
        );

        bytes memory encodedCompose = OFTComposeMsgCodec.encode(
            1,
            TEST.CONFIG.dstLzV2Id,
            amount,
            abi.encodePacked(OFTComposeMsgCodec.addressToBytes32(lzOftAdapter), composeMsg)
        );

        deal(usdc, address(oftBridgeAdapter), amount);

        vm.prank(lzEndpoint);

        oftBridgeAdapter.lzCompose(
            lzOftAdapter,
            "",
            encodedCompose,
            address(0), /*_executor*/
            ""
        );
    }
}
