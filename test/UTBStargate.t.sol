// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// forge contracts
import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// test fixture
import {EthereumFixture} from "./common/EthereumFixture.sol";

// utb contracts
import {SwapInstructions, BridgeInstructions, SwapAndExecuteInstructions, FeeData, Fee} from "../src/UTB.sol";
import {SwapParams, SwapDirection} from "../src/CommonTypes.sol";
import {IBridgeAdapter} from "../src/interfaces/IBridgeAdapter.sol";

// helper contracts
import {VeryCoolCat} from "./helpers/VeryCoolCat.sol";

// stargate contracts
import {IStargateRouter, LzBridgeData} from "../src/bridge_adapters/stargate/IStargateRouter.sol";

import {VmSafe} from "forge-std/Vm.sol";
import {ILayerZeroEndpoint} from "@layerzerolabs/solidity-examples/contracts/lzApp/interfaces/ILayerZeroEndpoint.sol";

interface IPool {
    function mint(address _to, uint256 _amountLD) external;
}

abstract contract MockEndpoint is ILayerZeroEndpoint {
    address public defaultReceiveLibraryAddress;
}

contract UTBStargateTest is Test, EthereumFixture {
    uint nativeFee = 0.00001 ether;
    address feeRecipient = address(0x1CE0FFEE);
    VeryCoolCat cat;
    uint64 GAS_TO_MINT = 500_000;
    address payable refund;
    uint8 constant SG_FUNCTION_TYPE_SWAP_REMOTE = 1;
    uint16 constant SG_SLIPPAGE_BPS = 1_00;
    uint120 ETH_POOL = 13;
    uint120 DAI_POOL = 3;
    uint256 amount;
    uint256 amountToStargate;
    address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    function setUp() public {
        cat = new VeryCoolCat();
        cat.setWeth(address(TEST.CONFIG.weth));
        refund = payable(TEST.EOA.alice);
        amount = cat.ethPrice();
        amountToStargate = (amount * (100_00 + SG_SLIPPAGE_BPS)) / 100_00;
        deal(TEST.EOA.alice, 1000 ether);
    }

    function test_bridgeAndExecute_stargate_with_slippage() public {
        (
            BridgeInstructions memory bridgeInstructions,
            FeeData memory feeData,
            bytes memory signature
        ) = _getBridgeAndExecuteParams(SG_SLIPPAGE_BPS);

        // vm.recordLogs();

        TEST.SRC.utb.bridgeAndExecute{value: amountToStargate + nativeFee + feeData.bridgeFee}(
            bridgeInstructions,
            feeData,
            signature
        );

        // deliverLzMessageAtDestination(GAS_TO_MINT);

        uint nativeBalance = address(feeRecipient).balance;
        assertEq(nativeBalance, nativeFee);

        // uint nftBalance = cat.balanceOf(TEST.EOA.alice);
        // assertEq(nftBalance, 1);
    }

    function test_bridgeAndExecute_stargate_precisionTooHigh() public {
        (
            BridgeInstructions memory bridgeInstructions,
            FeeData memory feeData,
            bytes memory signature
        ) = _getBridgeAndExecuteParams(SG_SLIPPAGE_BPS);

        vm.prank(TEST.EOA.deployer);

        TEST.SRC.stargateBridgeAdapter.registerRemoteBridgeAdapter(
            TEST.CONFIG.dstChainId,
            uint16(TEST.LZ.dstId),
            16,
            address(TEST.DST.stargateBridgeAdapter)
        );

        vm.expectRevert(bytes4(keccak256("RemotePrecisionExceeded()")));

        TEST.SRC.utb.bridgeAndExecute{value: amountToStargate + nativeFee + feeData.bridgeFee}(
            bridgeInstructions,
            feeData,
            signature
        );
    }

    function test_bridgeAndExecute_stargate_refundDust() public {
        uint256 amountHP = 0.123456789123456789 ether;
        uint256 dust = 0.000000789123456789 ether;
        uint16 dstChainId = 111; // optimism

        BridgeInstructions memory bridgeInstructions = BridgeInstructions({
            preBridge: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: dai,
                    amountIn: amountHP,
                    tokenOut: dai,
                    amountOut: amountHP,
                    dustOut: 0,
                    direction: SwapDirection.EXACT_IN,
                    refund: refund,
                    additionalArgs: ""
                })
            }),
            postBridge: SwapInstructions({
                swapperId: TEST.DST.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: dai,
                    amountIn: amount,
                    tokenOut: address(0),
                    amountOut: amount,
                    dustOut: 0,
                    direction: SwapDirection.EXACT_IN,
                    refund: refund,
                    additionalArgs: ""
                })
            }),
            bridgeId: TEST.SRC.stargateBridgeAdapter.ID(),
            dstChainId: dstChainId,
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            payload: abi.encodeCall(cat.mintWithEth, (TEST.EOA.alice)),
            additionalArgs: "", // abi.encode(TEST.CONFIG.stargateEth)
            txId: ""
        });

        (uint256 lzNativeFee, ) = IStargateRouter(TEST.CONFIG.stargateComposer).quoteLayerZeroFee(
            TEST.CONFIG.dstLzV1Id,
            SG_FUNCTION_TYPE_SWAP_REMOTE,
            abi.encodePacked(
                address(TEST.DST.stargateBridgeAdapter)
            ),
            abi.encode(
                bridgeInstructions.postBridge,
                address(cat),
                bridgeInstructions.payload,
                refund
            ),
            IStargateRouter.lzTxObj({
                dstGasForCall: GAS_TO_MINT,
                dstNativeAmount: 0,
                dstNativeAddr: ""
            })
        );

        bridgeInstructions.additionalArgs = abi.encode(
            dai, // bridge token
            LzBridgeData({
                _srcPoolId: DAI_POOL,
                _dstPoolId: DAI_POOL,
                _dstChainId: dstChainId,
                _bridgeAddress: address(TEST.DST.stargateBridgeAdapter),
                fee: uint96((lzNativeFee * 140) / 100)
            }),
            IStargateRouter.lzTxObj({
                dstGasForCall: GAS_TO_MINT,
                dstNativeAmount: 0,
                dstNativeAddr: ""
            }),
            SG_SLIPPAGE_BPS
        );

        FeeData memory feeData = FeeData({
            appId: bytes4(0),
            affiliateId: bytes4(0),
            bridgeFee: (lzNativeFee * 140) / 100,
            deadline: block.timestamp,
            chainId: block.chainid,
            appFees: new Fee[](1)
        });

        feeData.appFees[0] = Fee({
            recipient: feeRecipient,
            token: address(0),
            amount: nativeFee
        });

        bytes memory signature = getSignature(abi.encode(bridgeInstructions, feeData));

        vm.prank(TEST.EOA.deployer);

        // register decimals to a dst bridge adapter with non-zero address
        TEST.SRC.stargateBridgeAdapter.registerRemoteBridgeAdapter(
            dstChainId,
            uint16(TEST.LZ.dstId),
            18,
            address(TEST.DST.stargateBridgeAdapter)
        );

        deal(dai, TEST.EOA.alice, amountHP);

        vm.startPrank(TEST.EOA.alice);

        IERC20(dai).approve(address(TEST.SRC.utb), amountHP);

        TEST.SRC.utb.bridgeAndExecute{value: nativeFee + feeData.bridgeFee}(
            bridgeInstructions,
            feeData,
            signature
        );

        vm.stopPrank();

        assertEq(IERC20(dai).balanceOf(TEST.EOA.alice), dust);
    }

    function test_bridgeAndExecute_stargate_without_slippage() public {
        (
            BridgeInstructions memory bridgeInstructions,
            FeeData memory feeData,
            bytes memory signature
        ) = _getBridgeAndExecuteParams(0); // slippage

        vm.expectRevert("Stargate: slippage too high");

        TEST.SRC.utb.bridgeAndExecute{value: amountToStargate + nativeFee + feeData.bridgeFee}(
            bridgeInstructions,
            feeData,
            signature
        );
    }

    function test_bridgeAndExecuteNotEnoughGasForRelay() public {
        (
            BridgeInstructions memory bridgeInstructions,
            FeeData memory feeData,
            /*bytes memory signature*/
        ) = _getBridgeAndExecuteParams(0); // slippage

        (
            address bridgeToken,
            LzBridgeData memory lzBridgeData,
            IStargateRouter.lzTxObj memory lzTxObj,
            uint16 slippage
        ) = abi.decode(
            bridgeInstructions.additionalArgs,
            (address, LzBridgeData, IStargateRouter.lzTxObj, uint16)
        );

        bridgeInstructions.additionalArgs = abi.encode(
            bridgeToken,
            lzBridgeData,
            IStargateRouter.lzTxObj({
                dstGasForCall: 0,
                dstNativeAmount: lzTxObj.dstNativeAmount,
                dstNativeAddr: lzTxObj.dstNativeAddr
            }),
            slippage
        );

        bytes memory signature = getSignature(abi.encode(bridgeInstructions, feeData));

        vm.expectRevert(bytes4(keccak256("NotEnoughGasForRelay()")));

        TEST.SRC.utb.bridgeAndExecute{value: amountToStargate + nativeFee + feeData.bridgeFee}(
            bridgeInstructions,
            feeData,
            signature
        );
    }

    function test_sgReceiveSgEthRefund() public {
        uint256 refundBefore = refund.balance;

        (
            BridgeInstructions memory bridgeInstructions,
            /*FeeData memory feeData*/,
            /*bytes memory signature*/
        ) = _getBridgeAndExecuteParams(SG_SLIPPAGE_BPS);

        bytes memory payload = abi.encode(
            bridgeInstructions.postBridge,
            address(cat),
            address(cat),
            abi.encodeCall(cat.mintWithUsdc, (TEST.EOA.alice)),
            refund
        );

        deal(address(TEST.DST.stargateBridgeAdapter), amount);
        vm.prank(TEST.CONFIG.stargateComposer);

        TEST.DST.stargateBridgeAdapter.sgReceive(
            TEST.CONFIG.dstLzV1Id,
            "",
            0,
            TEST.CONFIG.stargateEth,
            amount,
            payload
        );

        assertEq(refund.balance, refundBefore + amount);
    }

    function test_sgReceiveInsufficientFundsRefund() public {
        uint256 refundBefore = refund.balance;

        (
            BridgeInstructions memory bridgeInstructions,
            /*FeeData memory feeData*/,
            /*bytes memory signature*/
        ) = _getBridgeAndExecuteParams(SG_SLIPPAGE_BPS);

        bytes memory payload = abi.encode(
            bridgeInstructions.postBridge,
            address(cat),
            address(cat),
            abi.encodeCall(cat.mintWithEth, (TEST.EOA.alice)),
            refund
        );

        uint256 slippedAmount = amount * 90 / 100;
        deal(address(TEST.DST.stargateBridgeAdapter), slippedAmount);
        vm.prank(TEST.CONFIG.stargateComposer);

        TEST.DST.stargateBridgeAdapter.sgReceive(
            TEST.CONFIG.dstLzV1Id,
            "",
            0,
            TEST.CONFIG.stargateEth,
            slippedAmount,
            payload
        );

        assertEq(refund.balance, refundBefore + slippedAmount);
    }

    function test_sgReceiveTokenMismatchRefund() public {
        uint256 refundBefore = refund.balance;

        (
            BridgeInstructions memory bridgeInstructions,
            /*FeeData memory feeData*/,
            /*bytes memory signature*/
        ) = _getBridgeAndExecuteParams(SG_SLIPPAGE_BPS);

        bridgeInstructions.postBridge.swapParams = SwapParams({
            tokenIn: TEST.CONFIG.weth,
            amountIn: amount,
            tokenOut: address(0),
            amountOut: amount,
            dustOut: 0,
            direction: SwapDirection.EXACT_OUT,
            refund: refund,
            additionalArgs: ""
        });

        bytes memory payload = abi.encode(
            bridgeInstructions.postBridge,
            address(cat),
            address(cat),
            abi.encodeCall(cat.mintWithEth, (TEST.EOA.alice)),
            refund
        );

        deal(address(TEST.DST.stargateBridgeAdapter), amount);
        vm.prank(TEST.CONFIG.stargateComposer);

        TEST.DST.stargateBridgeAdapter.sgReceive(
            TEST.CONFIG.dstLzV1Id,
            "",
            0,
            TEST.CONFIG.stargateEth,
            amount,
            payload
        );

        assertEq(refund.balance, refundBefore + amount);
    }

    function _getBridgeAndExecuteParams(uint16 slippage) private returns (
        BridgeInstructions memory bridgeInstructions,
        FeeData memory feeData,
        bytes memory signature
    ) {
        bridgeInstructions = BridgeInstructions({
            preBridge: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: address(0),
                    amountIn: amountToStargate,
                    tokenOut: address(0),
                    amountOut: amountToStargate,
                    dustOut: 0,
                    direction: SwapDirection.EXACT_OUT,
                    refund: refund,
                    additionalArgs: ""
                })
            }),
            postBridge: SwapInstructions({
                swapperId: TEST.DST.uniSwapper.ID(),
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
            bridgeId: TEST.SRC.stargateBridgeAdapter.ID(),
            dstChainId: TEST.CONFIG.dstChainId,
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            payload: abi.encodeCall(cat.mintWithEth, (TEST.EOA.alice)),
            additionalArgs: "", // abi.encode(TEST.CONFIG.stargateEth)
            txId: ""
        });

        (uint256 lzNativeFee, ) = IStargateRouter(TEST.CONFIG.stargateComposer).quoteLayerZeroFee(
            TEST.CONFIG.dstLzV1Id,
            SG_FUNCTION_TYPE_SWAP_REMOTE,
            abi.encodePacked(
                address(TEST.DST.stargateBridgeAdapter)
            ),
            abi.encode(
                bridgeInstructions.postBridge,
                address(cat),
                bridgeInstructions.payload,
                refund
            ),
            IStargateRouter.lzTxObj({
                dstGasForCall: GAS_TO_MINT,
                dstNativeAmount: 0,
                dstNativeAddr: ""
            })
        );

        bridgeInstructions.additionalArgs = abi.encode(
            address(0), // bridge token
            LzBridgeData({
                _srcPoolId: ETH_POOL,
                _dstPoolId: ETH_POOL,
                _dstChainId: TEST.CONFIG.dstLzV1Id,
                _bridgeAddress: address(TEST.DST.stargateBridgeAdapter),
                fee: uint96((lzNativeFee * 140) / 100)
            }),
            IStargateRouter.lzTxObj({
                dstGasForCall: GAS_TO_MINT,
                dstNativeAmount: 0,
                dstNativeAddr: ""
            }),
            slippage
        );

        feeData = FeeData({
            appId: bytes4(0),
            affiliateId: bytes4(0),
            bridgeFee: (lzNativeFee * 140) / 100,
            deadline: block.timestamp,
            chainId: block.chainid,
            appFees: new Fee[](1)
        });

        feeData.appFees[0] = Fee({
            recipient: feeRecipient,
            token: address(0),
            amount: nativeFee
        });

        signature = getSignature(abi.encode(bridgeInstructions, feeData));
    }

    function _getPacket() private returns (bytes memory) {
        VmSafe.Log[] memory entries = vm.getRecordedLogs();
        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("Packet(bytes)")) {
                console2.logBytes32(entries[i].topics[0]);
                console2.logBytes(entries[i].data);
                return entries[i].data;
            }
        }
        revert(string.concat("no packet was emitted"));
    }

    function _extractLzInfo(
        bytes memory packet
    )
        private
        pure
        returns (
            uint64 nonce,
            uint16 localChainId,
            address sourceUa,
            uint16 dstChainId,
            address dstAddress
        )
    {
        assembly {
            let start := add(packet, 64)
            nonce := mload(add(start, 8))
            localChainId := mload(add(start, 10))
            sourceUa := mload(add(start, 30))
            dstChainId := mload(add(start, 32))
            dstAddress := mload(add(start, 52))
        }
    }

    function _extractAppPayload(
        bytes memory packet
    ) private pure returns (bytes memory payload) {
        uint start = 64 + 52;
        uint payloadLength = packet.length - start;
        payload = new bytes(payloadLength);
        assembly {
            let payloadPtr := add(packet, start)
            let destPointer := add(payload, 32)
            for {
                let i := 32
            } lt(i, payloadLength) {
                i := add(i, 32)
            } {
                mstore(destPointer, mload(add(payloadPtr, i)))
                destPointer := add(destPointer, 32)
            }
        }
    }

    function deliverLzMessageAtDestination(
        uint gasLimit
    ) public {
        bytes memory packet = _getPacket();
        (
            /*uint64 nonce*/,
            /*uint16 localChainId*/,
            address sourceUa,
            /*uint16 dstChainId*/,
            address dstAddress
        ) = _extractLzInfo(packet);

        console2.log('sourceUa', sourceUa);
        console2.log('dstAddress', dstAddress);

        bytes memory payload = _extractAppPayload(packet);
        console2.log('payload');
        console2.logBytes(payload);
        receiveLzMessage(sourceUa, dstAddress, gasLimit, payload);
    }

    function receiveLzMessage(
        address srcUa,
        address dstUa,
        uint gasLimit,
        bytes memory payload
    ) public {

        MockEndpoint dstEndpoint = MockEndpoint(0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);

        bytes memory srcPath = abi.encodePacked(dstUa, srcUa);

        uint64 nonce = dstEndpoint.getInboundNonce(TEST.CONFIG.dstLzV1Id, srcPath);

        address defaultLibAddress = dstEndpoint.defaultReceiveLibraryAddress();

        vm.startPrank(defaultLibAddress);

        dstEndpoint.receivePayload(
            TEST.CONFIG.dstLzV1Id, // src chain id
            srcPath, // src address
            dstUa, // dst address
            nonce + 1, // nonce
            gasLimit, // gas limit
            payload // payload
        );

        vm.stopPrank();
    }
}
