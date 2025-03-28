// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// forge contracts
import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

// test fixture
import {EthereumFixture} from "./common/EthereumFixture.sol";

// utb contracts
import {SwapInstructions, SwapAndExecuteInstructions, FeeData, Fee} from "../src/UTB.sol";
import {SwapParams, SwapDirection} from "../src/CommonTypes.sol";

// helper contracts
import {VeryCoolCat} from "./helpers/VeryCoolCat.sol";
import {MockErc20} from "./helpers/MockErc20.sol";

contract UTBFeeCollector is Test, EthereumFixture {
    MockErc20 mockErc20;
    VeryCoolCat cat;
    uint256 amount;
    uint nativeFee = 1 ether;
    uint erc20Fee = 1e5;
    address refund;
    address feeRecipientNative = address(0x1CE0FFEE);
    address feeRecipientErc20 = address(0xC0CAC01A);

    function setUp() public {
        mockErc20 = new MockErc20('Mock', 'MOCK');
        cat = new VeryCoolCat();
        cat.setWeth(TEST.CONFIG.weth);
        amount = cat.wethPrice();
        refund = payable(TEST.EOA.alice);
    }

    function test_fees() public {
        (
            SwapAndExecuteInstructions memory swapAndExecuteInstructions,
            FeeData memory feeData,
            bytes memory signature
        ) = getSwapAndExecuteParams();

        deal(TEST.EOA.alice, 1000 ether);
        mockErc20.mint(TEST.EOA.alice, erc20Fee);

        vm.startPrank(TEST.EOA.alice);

        mockErc20.approve(address(TEST.SRC.utb), erc20Fee);

        TEST.SRC.utb.swapAndExecute{value: amount + nativeFee}(
            swapAndExecuteInstructions,
            feeData,
            signature
        );

        uint nativeBalance = address(feeRecipientNative).balance;
        assertEq(nativeBalance, nativeFee);

        uint erc20Balance = mockErc20.balanceOf(feeRecipientErc20);
        assertEq(erc20Balance, erc20Fee);
    }

    function test_feesNotEnoughNative() public {
        (
            SwapAndExecuteInstructions memory swapAndExecuteInstructions,
            FeeData memory feeData,
            bytes memory signature
        ) = getSwapAndExecuteParams();

        deal(TEST.EOA.alice, 1000 ether);
        mockErc20.mint(TEST.EOA.alice, erc20Fee);

        vm.startPrank(TEST.EOA.alice);

        mockErc20.approve(address(TEST.SRC.utb), erc20Fee);

        vm.expectRevert(bytes4(keccak256("NotEnoughNative()")));

        TEST.SRC.utb.swapAndExecute{value: amount + nativeFee - 1}(
            swapAndExecuteInstructions,
            feeData,
            signature
        );
    }

    function getSwapAndExecuteParams() public returns (
        SwapAndExecuteInstructions memory swapAndExecuteInstructions,
        FeeData memory feeData,
        bytes memory signature
    ) {
        SwapParams memory swapParams = SwapParams({
            tokenIn: address(0),
            amountIn: amount,
            tokenOut: TEST.CONFIG.weth,
            amountOut: amount,
            dustOut: 0,
            direction: SwapDirection.EXACT_OUT,
            refund: refund,
            additionalArgs: ""
        });

        SwapInstructions memory swapInstructions = SwapInstructions({
            swapperId: TEST.SRC.uniSwapper.ID(),
            swapParams: swapParams
        });

        swapAndExecuteInstructions = SwapAndExecuteInstructions({
            swapInstructions: swapInstructions,
            target: address(cat),
            paymentOperator: address(cat),
            refund: refund,
            executionFee: 0,
            payload: abi.encodeCall(cat.mintWithWeth, (TEST.EOA.alice)),
            txId: ""
        });

        feeData = _nativeAndErc20FeeData();

        signature = getSignature(abi.encode(swapAndExecuteInstructions, feeData));
    }

    function _nativeAndErc20FeeData() internal view returns (FeeData memory feeData) {
        Fee[] memory appFees = new Fee[](2);

        appFees[0] = Fee({
            recipient: feeRecipientNative,
            token: address(0),
            amount: nativeFee
        });

        appFees[1] = Fee({
            recipient: feeRecipientErc20,
            token: address(mockErc20),
            amount: erc20Fee
        });

        feeData = FeeData({
            appId: bytes4(0),
            affiliateId: bytes4(0),
            bridgeFee: 0,
            deadline: block.timestamp,
            chainId: block.chainid,
            appFees: appFees
        });
    }
}
