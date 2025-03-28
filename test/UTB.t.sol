// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// forge contracts
import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

// test fixture
import {EthereumFixture} from "./common/EthereumFixture.sol";

// utb contracts
import {SwapInstructions, BridgeInstructions, SwapAndExecuteInstructions, FeeData, Fee} from "../src/UTB.sol";
import {SwapParams, SwapDirection} from "../src/CommonTypes.sol";
import {IUTB} from "../src/interfaces/IUTB.sol";

// helper contracts
import {VeryCoolCat} from "./helpers/VeryCoolCat.sol";

// layerzero contracts
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";

// openzeppelin contracts
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UTBTest is Test, EthereumFixture {
    uint nativeFee = 0.00001 ether;
    address feeRecipient = address(0x1CE0FFEE);
    VeryCoolCat cat;
    uint64 GAS_TO_MINT = 500_000;
    address payable refund;
    bytes bridgeAdapterCall;
    BridgeInstructions bridgeInstructions;
    bytes32 public constant TRANSACTION_ID = keccak256("TRANSACTION_ID");

    using OptionsBuilder for bytes;

    function setUp() public {
        cat = new VeryCoolCat();
        cat.setWeth(address(TEST.CONFIG.weth));
        refund = payable(TEST.EOA.alice);
        deal(TEST.EOA.alice, 1000 ether);
    }

    function test_swapAndExecute_example() public {
        uint256 amount = cat.wethPrice();

        SwapAndExecuteInstructions memory swapAndExecInstructions = SwapAndExecuteInstructions({
            swapInstructions: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: address(0),
                    amountIn: amount,
                    tokenOut: address(TEST.CONFIG.weth),
                    amountOut: amount,
                    dustOut: 0,
                    direction: SwapDirection.EXACT_OUT,
                    refund: refund,
                    additionalArgs: ""
                })
            }),
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            executionFee: 0,
            payload: abi.encodeCall(cat.mintWithWeth, (TEST.EOA.alice)),
            txId: TRANSACTION_ID
        });

        FeeData memory feeData = FeeData({
            appId: bytes4(0),
            affiliateId: bytes4(0),
            bridgeFee: 0,
            deadline: block.timestamp,
            chainId: block.chainid,
            appFees: new Fee[](1)
        });

        feeData.appFees[0] = Fee({
            recipient: feeRecipient,
            token: address(0),
            amount: nativeFee
        });

        vm.expectEmit(true, true, false, true);
        emit IUTB.Swapped(
            TRANSACTION_ID,
            feeData.appId,
            IUTB.TxInfo({
                amountIn: swapAndExecInstructions.swapInstructions.swapParams.amountIn,
                tokenIn: swapAndExecInstructions.swapInstructions.swapParams.tokenIn,
                tokenOut: swapAndExecInstructions.swapInstructions.swapParams.tokenOut,
                target: swapAndExecInstructions.target,
                affiliateId: feeData.affiliateId,
                fees: feeData.appFees
            })
        );

        vm.prank(TEST.EOA.alice);

        TEST.SRC.utb.swapAndExecute{value: amount + nativeFee}(
            swapAndExecInstructions,
            feeData,
            getSignature(abi.encode(swapAndExecInstructions, feeData))
        );

        uint nativeBalance = address(feeRecipient).balance;
        assertEq(nativeBalance, nativeFee);

        uint nftBalance = cat.balanceOf(TEST.EOA.alice);
        assertEq(nftBalance, 1);
    }

    function test_swapAndExecute_with_execution_fee() public {
        uint256 amount = cat.wethPrice();
        uint256 executionFee = cat.executionFee();

        SwapAndExecuteInstructions memory swapAndExecInstructions = SwapAndExecuteInstructions({
            swapInstructions: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: address(0),
                    amountIn: amount,
                    tokenOut: address(TEST.CONFIG.weth),
                    amountOut: amount,
                    dustOut: 0,
                    direction: SwapDirection.EXACT_OUT,
                    refund: refund,
                    additionalArgs: ""
                })
            }),
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            executionFee: executionFee,
            payload: abi.encodeCall(cat.mintWithWethPlusFee, (TEST.EOA.alice)),
            txId: TRANSACTION_ID
        });

        FeeData memory feeData = FeeData({
            appId: bytes4(0),
            affiliateId: bytes4(0),
            bridgeFee: 0,
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

        TEST.SRC.utb.swapAndExecute{value: amount + nativeFee + executionFee}(
            swapAndExecInstructions,
            feeData,
            getSignature(abi.encode(swapAndExecInstructions, feeData))
        );

        uint nativeBalance = address(feeRecipient).balance;
        assertEq(nativeBalance, nativeFee);

        uint nftBalance = cat.balanceOf(TEST.EOA.alice);
        assertEq(nftBalance, 1);

        vm.expectRevert(bytes4(keccak256("ExecutionFailed()")));

        swapAndExecInstructions.executionFee = 0;

        TEST.SRC.utb.swapAndExecute{value: amount + nativeFee}(
            swapAndExecInstructions,
            feeData,
            getSignature(abi.encode(swapAndExecInstructions, feeData))
        );
    }

    function _roundUpDust(uint256 withDust) private view returns (uint256 rounded) {
        uint256 rate = TEST.SRC.dcntEth.decimalConversionRate();
        uint256 withoutDust = (withDust / rate) * rate;
        rounded = withDust - withoutDust > 0
            ? withoutDust + rate
            : withoutDust;
    }

    function test_bridgeAndExecute_example() public {
        uint256 amountHP = cat.ethPrice();
        uint256 amount = _roundUpDust(amountHP);

        bridgeInstructions = BridgeInstructions({
            preBridge: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: address(0),
                    amountIn: amount,
                    tokenOut: address(0),
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
                    tokenIn: address(TEST.CONFIG.weth),
                    amountIn: amount,
                    tokenOut: address(0),
                    amountOut: amount,
                    dustOut: amount - amountHP,
                    direction: SwapDirection.EXACT_OUT,
                    refund: refund,
                    additionalArgs: ""
                })
            }),
            bridgeId: TEST.SRC.decentBridgeAdapter.ID(),
            dstChainId: TEST.CONFIG.dstChainId,
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            payload: abi.encodeCall(cat.mintWithEth, (TEST.EOA.alice)),
            additionalArgs: abi.encode(GAS_TO_MINT),
            txId: TRANSACTION_ID
        });

        bridgeAdapterCall = abi.encodeCall(
            TEST.DST.decentBridgeAdapter.receiveFromBridge,
            (
                bridgeInstructions.postBridge, // post bridge
                address(cat), // target
                address(cat), // paymentOperator
                bridgeInstructions.payload, // payload
                refund, // refund
                TRANSACTION_ID // txId
            )
        );

        (uint lzNativeFee, /*uint lzZroFee*/) = TEST.SRC.decentBridgeAdapter.estimateFees(
            bridgeInstructions.postBridge,
            TEST.CONFIG.dstChainId,
            address(TEST.DST.decentBridgeAdapter),
            GAS_TO_MINT,
            bridgeAdapterCall
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

        vm.expectEmit(true, true, true, true);
        emit IUTB.BridgeCalled(
            TRANSACTION_ID,
            feeData.appId,
            bridgeInstructions.dstChainId,
            IUTB.TxInfo({
                amountIn: bridgeInstructions.preBridge.swapParams.amountIn,
                tokenIn: bridgeInstructions.preBridge.swapParams.tokenIn,
                tokenOut: bridgeInstructions.postBridge.swapParams.tokenOut,
                target: bridgeInstructions.target,
                affiliateId: feeData.affiliateId,
                fees: feeData.appFees
            })
        );

        vm.prank(TEST.EOA.alice);

        TEST.SRC.utb.bridgeAndExecute{value: amount + nativeFee + lzNativeFee}(
            bridgeInstructions,
            feeData,
            getSignature(abi.encode(bridgeInstructions, feeData))
        );

        bytes32 guid = getNextInflightPacketGuid(
            TEST.LZ.dstId,
            addressToBytes32(address(TEST.DST.dcntEth))
        );

        verifyPackets(
            TEST.LZ.dstId,
            addressToBytes32(address(TEST.DST.dcntEth))
        );

        bytes memory options = OptionsBuilder.newOptions()
            .addExecutorLzReceiveOption(TEST.DST.decentEthRouter.gasForRelay(), 0)
            .addExecutorLzComposeOption(0, GAS_TO_MINT, 0);

        bytes memory message = OFTComposeMsgCodec.encode(
            1, // nonce
            TEST.LZ.srcId,
            amount,
            abi.encodePacked(
                addressToBytes32(address(TEST.SRC.decentEthRouter)),
                abi.encode(
                    TEST.SRC.decentEthRouter.MT_ETH_TRANSFER_WITH_PAYLOAD(),
                    TEST.DST.decentBridgeAdapter,
                    refund,
                    false,
                    bridgeAdapterCall
                )
            )
        );

        vm.expectEmit(true, false, false, true);
        emit IUTB.ReceivedFromBridge(TRANSACTION_ID);

        this.lzCompose(
            TEST.LZ.dstId,
            address(TEST.DST.dcntEth),
            options,
            guid,
            address(TEST.DST.decentEthRouter),
            message
        );

        uint nativeBalance = address(feeRecipient).balance;
        assertEq(nativeBalance, nativeFee);

        uint nftBalance = cat.balanceOf(TEST.EOA.alice);
        assertEq(nftBalance, 1);
    }

    function test_bridgeAndExecute_refundDust() public {
        uint256 aliceBefore = TEST.EOA.alice.balance;
        uint256 amountHP = 0.123456789123456789 ether;
        uint256 amount = 0.123456 ether;

        (uint256 lzNativeFee, /*uint256 zroFee*/) = TEST.SRC.decentEthRouter.estimateSendAndCallFee(
            TEST.SRC.decentEthRouter.MT_ETH_TRANSFER(),
            TEST.LZ.dstId,
            TEST.EOA.alice,
            TEST.EOA.alice,
            amountHP,
            0, // gas
            true,
            "" // payload
        );

        vm.prank(TEST.EOA.alice);

        TEST.SRC.decentEthRouter.bridge{value: amountHP + lzNativeFee}(
            TEST.LZ.dstId,
            TEST.EOA.alice,
            TEST.EOA.alice,
            amountHP,
            0, // gas
            true
        );

        assertEq(TEST.EOA.alice.balance, aliceBefore - (amount + lzNativeFee));
    }

    function test_bridgeAndExecute_precisionTooHigh() public {
        uint256 amountHP = cat.ethPrice();
        uint256 amount = _roundUpDust(amountHP);

        bridgeInstructions = BridgeInstructions({
            preBridge: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: address(0),
                    amountIn: amount,
                    tokenOut: address(0),
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
                    tokenIn: address(TEST.CONFIG.weth),
                    amountIn: amount,
                    tokenOut: address(0),
                    amountOut: amount,
                    dustOut: amount - amountHP,
                    direction: SwapDirection.EXACT_OUT,
                    refund: refund,
                    additionalArgs: ""
                })
            }),
            bridgeId: TEST.SRC.decentBridgeAdapter.ID(),
            dstChainId: TEST.CONFIG.dstChainId,
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            payload: abi.encodeCall(cat.mintWithEth, (TEST.EOA.alice)),
            additionalArgs: abi.encode(GAS_TO_MINT),
            txId: TRANSACTION_ID
        });

        bridgeAdapterCall = abi.encodeCall(
            TEST.DST.decentBridgeAdapter.receiveFromBridge,
            (
                bridgeInstructions.postBridge, // post bridge
                address(cat), // target
                address(cat), // paymentOperator
                bridgeInstructions.payload, // payload
                refund, // refund
                TRANSACTION_ID // txId
            )
        );

        (uint lzNativeFee, /*uint lzZroFee*/) = TEST.SRC.decentBridgeAdapter.estimateFees(
            bridgeInstructions.postBridge,
            TEST.CONFIG.dstChainId,
            address(TEST.DST.decentBridgeAdapter),
            GAS_TO_MINT,
            bridgeAdapterCall
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

        vm.prank(TEST.EOA.deployer);

        TEST.SRC.decentBridgeAdapter.registerRemoteBridgeAdapter(
            TEST.CONFIG.dstChainId,
            TEST.LZ.dstId,
            16,
            address(TEST.DST.decentBridgeAdapter)
        );

        vm.prank(TEST.EOA.alice);

        vm.expectRevert(bytes4(keccak256("RemotePrecisionExceeded()")));

        TEST.SRC.utb.bridgeAndExecute{value: amount + nativeFee + lzNativeFee}(
            bridgeInstructions,
            feeData,
            getSignature(abi.encode(bridgeInstructions, feeData))
        );
    }

    function test_swapAndExecute_refunds_overpay() public {
        uint256 amount = cat.wethPrice();
        uint256 aliceBefore = TEST.EOA.alice.balance;

        SwapAndExecuteInstructions memory swapAndExecInstructions = SwapAndExecuteInstructions({
            swapInstructions: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: address(0),
                    amountIn: amount,
                    tokenOut: address(TEST.CONFIG.weth),
                    amountOut: amount,
                    dustOut: 0,
                    direction: SwapDirection.EXACT_OUT,
                    refund: refund,
                    additionalArgs: ""
                })
            }),
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            executionFee: 0,
            payload: abi.encodeCall(cat.mintWithWeth, (TEST.EOA.alice)),
            txId: TRANSACTION_ID
        });

        FeeData memory feeData = FeeData({
            appId: bytes4(0),
            affiliateId: bytes4(0),
            bridgeFee: 0,
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

        TEST.SRC.utb.swapAndExecute{value: amount + nativeFee + 1 ether}(
            swapAndExecInstructions,
            feeData,
            getSignature(abi.encode(swapAndExecInstructions, feeData))
        );

        assertEq(address(TEST.SRC.utb).balance, 0);
        assertEq(TEST.EOA.alice.balance, aliceBefore - amount - nativeFee);
    }

    function test_bridgeAndExecute_refunds_overpay() public {
        uint256 amount = _roundUpDust(cat.ethPrice());
        uint256 aliceBefore = TEST.EOA.alice.balance;

        bridgeInstructions = BridgeInstructions({
            preBridge: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: address(0),
                    amountIn: amount,
                    tokenOut: address(0),
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
                    tokenIn: address(TEST.CONFIG.weth),
                    amountIn: amount,
                    tokenOut: address(0),
                    amountOut: amount,
                    dustOut: 0,
                    direction: SwapDirection.EXACT_OUT,
                    refund: refund,
                    additionalArgs: ""
                })
            }),
            bridgeId: TEST.SRC.decentBridgeAdapter.ID(),
            dstChainId: TEST.CONFIG.dstChainId,
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            payload: abi.encodeCall(cat.mintWithEth, (TEST.EOA.alice)),
            additionalArgs: abi.encode(GAS_TO_MINT),
            txId: TRANSACTION_ID
        });

        bridgeAdapterCall = abi.encodeCall(
            TEST.DST.decentBridgeAdapter.receiveFromBridge,
            (
                bridgeInstructions.postBridge, // post bridge
                address(cat), // target
                address(cat), // paymentOperator
                bridgeInstructions.payload, // payload
                refund, // refund
                TRANSACTION_ID // txId
            )
        );

        (uint lzNativeFee, /*uint lzZroFee*/) = TEST.SRC.decentBridgeAdapter.estimateFees(
            bridgeInstructions.postBridge,
            TEST.CONFIG.dstChainId,
            address(TEST.DST.decentBridgeAdapter),
            GAS_TO_MINT,
            bridgeAdapterCall
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

        TEST.SRC.utb.bridgeAndExecute{value: amount + nativeFee + lzNativeFee + 1 ether}(
            bridgeInstructions,
            feeData,
            getSignature(abi.encode(bridgeInstructions, feeData))
        );

        assertEq(address(TEST.SRC.utb).balance, 0);
        assertEq(TEST.EOA.alice.balance, aliceBefore - amount - nativeFee - lzNativeFee);
    }

    function test_swapAndExecuteUSDT_refunds_overpay() public {
        address usdtMainnet = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        uint256 amountIn = cat.ethPrice();
        uint256 amountOut = cat.usdtPrice();
        cat.setUsdt(usdtMainnet);
        uint256 aliceBefore = TEST.EOA.alice.balance;

        SwapAndExecuteInstructions memory swapAndExecInstructions = SwapAndExecuteInstructions({
            swapInstructions: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: address(0),
                    amountIn: amountIn,
                    tokenOut: usdtMainnet, // USDT
                    amountOut: amountOut,
                    dustOut: 0,
                    direction: SwapDirection.EXACT_OUT,
                    refund: refund,
                    additionalArgs: abi.encodePacked(usdtMainnet, uint24(500), TEST.CONFIG.weth)
                })
            }),
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            executionFee: 0,
            payload: abi.encodeCall(cat.mintWithUsdt, (TEST.EOA.alice)),
            txId: TRANSACTION_ID
        });

        FeeData memory feeData = FeeData({
            appId: bytes4(0),
            affiliateId: bytes4(0),
            bridgeFee: 0,
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

        TEST.SRC.utb.swapAndExecute{value: amountIn + nativeFee + 1 ether}(
            swapAndExecInstructions,
            feeData,
            getSignature(abi.encode(swapAndExecInstructions, feeData))
        );

        assertEq(address(TEST.SRC.utb).balance, 0);
        assertEq(TEST.EOA.alice.balance, aliceBefore - amountIn - nativeFee);
        assertEq(cat.balanceOf(TEST.EOA.alice), 1);
    }

    function test_withdrawable_native() public {
        // Check initial balances
        uint256 initialAliceBalance = TEST.EOA.alice.balance;
        assertEq(address(TEST.SRC.utb).balance, 0);

        // Send some ETH to UTB
        uint256 amount = 1 ether;
        vm.deal(address(TEST.SRC.utb), amount);
        assertEq(address(TEST.SRC.utb).balance, amount);

        // Admin withdraws native
        vm.prank(TEST.EOA.deployer);
        TEST.SRC.utb.withdraw(TEST.EOA.alice, amount);

        // Verify balances after withdrawal
        assertEq(address(TEST.SRC.utb).balance, 0);
        assertEq(TEST.EOA.alice.balance, initialAliceBalance + amount);
    }

    function test_withdrawable_erc20() public {
        // Check initial balances
        uint256 initialAliceBalance = IERC20(TEST.CONFIG.weth).balanceOf(TEST.EOA.alice);
        assertEq(IERC20(TEST.CONFIG.weth).balanceOf(address(TEST.SRC.utb)), 0);

        // Send some WETH to UTB
        uint256 amount = 1 ether;
        deal(address(TEST.CONFIG.weth), address(TEST.SRC.utb), amount);
        assertEq(IERC20(TEST.CONFIG.weth).balanceOf(address(TEST.SRC.utb)), amount);

        // Admin withdraws ERC20
        vm.prank(TEST.EOA.deployer);
        TEST.SRC.utb.withdrawERC20(address(TEST.CONFIG.weth), TEST.EOA.alice, amount);

        // Verify balances after withdrawal
        assertEq(IERC20(TEST.CONFIG.weth).balanceOf(address(TEST.SRC.utb)), 0);
        assertEq(IERC20(TEST.CONFIG.weth).balanceOf(TEST.EOA.alice), initialAliceBalance + amount);
    }
}
