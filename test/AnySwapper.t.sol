// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// forge contracts
import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

import {AnySwapper} from "../src/swappers/AnySwapper.sol";

// test fixture
import {EthereumFixture} from "./common/EthereumFixture.sol";

// helpers
import {SimpleSwapRouter} from './helpers/SimpleSwapRouter.sol';

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {SwapParams, SwapDirection} from "../src/CommonTypes.sol";

contract AnySwapperTest is Test, EthereumFixture {
    SimpleSwapRouter swapRouter;
    AnySwapper anySwapper;
    address payable refund;

    address dai;
    address weth;
    address alice;
    address utb;

    function setUp() public {
        swapRouter = new SimpleSwapRouter();
        anySwapper = TEST.SRC.anySwapper;
        weth = address(TEST.CONFIG.weth);
        dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        alice = TEST.EOA.alice;
        utb = address(TEST.SRC.utb);
        refund = payable(alice);
        deal(alice, 1000 ether);

        // load up our simple swapper w tokens
        deal(dai, address(swapRouter), 100);
        deal(address(weth), address(swapRouter), 100);
        assertEq(IERC20(dai).balanceOf(address(swapRouter)), 100);
        assertEq(IERC20(weth).balanceOf(address(swapRouter)), 100);

        // give alice some tokens
        deal(dai, alice, 100);
        deal(address(weth), alice, 100);
        assertEq(IERC20(dai).balanceOf(alice), 100);
        assertEq(IERC20(weth).balanceOf(alice), 100);

        vm.startPrank(alice);
    }

    function _encodeData(
        address router,
        uint256 amountIn,
        uint256 amountOut,
        address tokenIn,
        address tokenOut,
        bool isIn
    ) private view returns (bytes memory) {
        if (isIn) {
            return abi.encode(
                router,
                abi.encodeWithSignature(
                    "swapExactIn(uint256,uint256,address,address,address)",
                    amountIn, amountOut, tokenIn, tokenOut, address(anySwapper)
                )
            );
        }

        return abi.encode(
            router,
            abi.encodeWithSignature(
              "swapExactOut(uint256,uint256,address,address,address)",
              amountIn, amountOut, tokenIn, tokenOut, address(anySwapper)
            )
        );
    }

    function testSwapDaiToWETHExactIn() public {
        uint256 utbBalanceIn = 10;
        // uint256 amountIn = 9;
        uint256 amountOut = 8;
        // uint256 aliceBalanceIn = IERC20(dai).balanceOf(alice);
        // uint256 aliceBalanceOut = IERC20(weth).balanceOf(alice);
        uint256 utbBalanceOut = IERC20(weth).balanceOf(utb);
        IERC20(dai).transfer(utb, utbBalanceIn);
        vm.startPrank(utb);
        IERC20(dai).approve(address(anySwapper), utbBalanceIn);

        // (SwapParams memory swapParams, address receiver, address refund, address router)
        SwapParams memory swapParams = SwapParams({
            tokenIn: dai,
            amountIn: utbBalanceIn,
            tokenOut: weth,
            amountOut: amountOut,
            dustOut: 0,
            direction: SwapDirection.EXACT_IN,
            refund: refund,
            additionalArgs: _encodeData(address(swapRouter),utbBalanceIn,amountOut,dai,weth,true)
        });

        anySwapper.swap(swapParams);

        assertEq(IERC20(dai).balanceOf(utb), 0);
        assertEq(IERC20(weth).balanceOf(utb), utbBalanceOut + amountOut);
    }

    function testSwapDaiToWETHExactOut() public {
        uint256 utbBalanceIn = 10;
        // uint256 amountIn = 9;
        uint256 amountOut = 8;
        // uint256 aliceBalanceIn = IERC20(dai).balanceOf(alice);
        // uint256 aliceBalanceOut = IERC20(weth).balanceOf(alice);
        uint256 utbBalanceOut = IERC20(weth).balanceOf(utb);
        IERC20(dai).transfer(utb, utbBalanceIn);
        vm.startPrank(utb);
        IERC20(dai).approve(address(anySwapper), utbBalanceIn);

        // (SwapParams memory swapParams, address receiver, address refund, address router)
        SwapParams memory swapParams = SwapParams({
            tokenIn: dai,
            amountIn: utbBalanceIn,
            tokenOut: weth,
            amountOut: amountOut,
            dustOut: 0,
            direction: SwapDirection.EXACT_OUT,
            refund: refund,
            additionalArgs: _encodeData(address(swapRouter),utbBalanceIn,amountOut,dai,weth,false)
        });

        anySwapper.swap(swapParams);

        assertEq(IERC20(dai).balanceOf(utb), 0);
        assertEq(IERC20(weth).balanceOf(utb), utbBalanceOut + amountOut);
    }
}
