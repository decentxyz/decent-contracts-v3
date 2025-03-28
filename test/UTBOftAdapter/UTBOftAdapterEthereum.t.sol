// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// forge contracts
import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

// test fixture
import {EthereumFixture} from "../common/EthereumFixture.sol";
import {UTBOftAdapterSetup} from "./UTBOftAdapterSetup.sol";

// utb contracts
import {SwapInstructions, BridgeInstructions, SwapAndExecuteInstructions, FeeData, Fee} from "../../src/UTB.sol";
import {SwapParams, SwapDirection} from "../../src/CommonTypes.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {OftBridgeAdapter} from "../../src/bridge_adapters/OftBridgeAdapter.sol";

// layerzero contracts
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {IOFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract UTBOftAdapterEthereum is UTBOftAdapterSetup, EthereumFixture {

    function test_bridgeAndExecute_oft_adapter_erc20_send() public {
        uint256 amount = 1 ether;

        address apeCoin = 0x4d224452801ACEd8B2F0aebE155379bb5D594381;
        address lzOftAdapter = 0x5182feDE730b31a9CF7f49C5781214B4a99F2370;

        vm.startPrank(TEST.EOA.deployer);
        TEST.SRC.oftBridgeAdapter.registerRemoteBridgeAdapter(
            TEST.CONFIG.dstChainId, TEST.CONFIG.dstLzV2Id, 18, address(TEST.DST.oftBridgeAdapter)
        );
        TEST.SRC.oftBridgeAdapter.permissionOft(apeCoin, lzOftAdapter);
        vm.stopPrank();

        deal(apeCoin, TEST.EOA.alice, 1 ether);

        bridgeInstructions = BridgeInstructions({
            preBridge: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: apeCoin,
                    amountIn: amount,
                    tokenOut: apeCoin,
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
                    tokenIn: apeCoin,
                    amountIn: amount,
                    tokenOut: apeCoin,
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
            payload: abi.encodeCall(cat.mintWithErc20, (TEST.EOA.alice, apeCoin, amount)),
            additionalArgs: abi.encode(apeCoin, GAS_TO_MINT, lzOftAdapter),
            txId: TRANSACTION_ID
        });

        (uint lzNativeFee, /*uint lzZroFee*/) = TEST.SRC.oftBridgeAdapter.estimateFees(
            IBridgeAdapter.BridgeCall({
                amount: amount,
                postBridge: bridgeInstructions.postBridge,
                dstChainId: TEST.CONFIG.dstChainId,
                target: bridgeInstructions.target,
                paymentOperator: bridgeInstructions.paymentOperator,
                payload: bridgeInstructions.payload,
                additionalArgs: bridgeInstructions.additionalArgs,
                refund: bridgeInstructions.refund,
                txId: TRANSACTION_ID
            })
        );

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
        IERC20(apeCoin).approve(address(TEST.SRC.utb), amount);

        vm.expectEmit(false, true, false, true);
        emit IOFT.OFTSent("", TEST.CONFIG.dstLzV2Id, address(TEST.SRC.oftBridgeAdapter), amount, amount);

        vm.prank(TEST.EOA.alice);
        TEST.SRC.utb.bridgeAndExecute{value: nativeFee + lzNativeFee}(
            bridgeInstructions,
            feeData,
            getSignature(abi.encode(bridgeInstructions, feeData))
        );
    }

    function test_bridgeAndExecute_oft_adapter_erc20_receive() public {
        uint256 amount = 1 ether;

        address apeCoin = 0x4d224452801ACEd8B2F0aebE155379bb5D594381;
        address lzOftAdapter = 0x5182feDE730b31a9CF7f49C5781214B4a99F2370;

        OftBridgeAdapter oftBridgeAdapter = TEST.SRC.oftBridgeAdapter;
        address lzEndpoint = 0x1a44076050125825900e736c501f859c50fE728c;

        vm.startPrank(TEST.EOA.deployer);
        oftBridgeAdapter.permissionOft(apeCoin, lzOftAdapter);
        vm.stopPrank();

        bytes memory composeMsg = abi.encode(
            SwapInstructions({
                swapperId: TEST.DST.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: apeCoin,
                    amountIn: amount,
                    tokenOut: apeCoin,
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

        deal(apeCoin, address(oftBridgeAdapter), amount);

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
