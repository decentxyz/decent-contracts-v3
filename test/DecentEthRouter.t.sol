// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {EthereumFixture} from "./common/EthereumFixture.sol";
import {IWETH} from "../src/interfaces/IWETH.sol";

contract DecentEthRouterTest is EthereumFixture {

    uint256 constant AMOUNT = 1 ether;

    modifier calledByAlice() {
        vm.startPrank(TEST.EOA.alice);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        deal(TEST.EOA.alice, AMOUNT);
        deal(address(TEST.CONFIG.weth), TEST.EOA.alice, AMOUNT);
    }

    function test_addLiquidityEth() public calledByAlice {
        uint256 aliceEthBefore = TEST.EOA.alice.balance;
        uint256 aliceDcntEthBefore = TEST.SRC.dcntEth.balanceOf(TEST.EOA.alice);

        TEST.SRC.decentEthRouter.addLiquidityEth{value: AMOUNT}();

        uint256 aliceEthAfter = TEST.EOA.alice.balance;
        uint256 aliceDcntEthAfter = TEST.SRC.dcntEth.balanceOf(TEST.EOA.alice);

        assertEq(aliceEthAfter, aliceEthBefore - AMOUNT, "ETH balance should decrease");
        assertEq(aliceDcntEthAfter, aliceDcntEthBefore + AMOUNT, "dcntEth balance should increase");
    }

    function test_addLiquidityWeth() public calledByAlice {
        IWETH(TEST.CONFIG.weth).approve(address(TEST.SRC.decentEthRouter), AMOUNT);

        uint256 aliceWethBefore = IWETH(TEST.CONFIG.weth).balanceOf(TEST.EOA.alice);
        uint256 aliceDcntEthBefore = TEST.SRC.dcntEth.balanceOf(TEST.EOA.alice);

        TEST.SRC.decentEthRouter.addLiquidityWeth(AMOUNT);

        uint256 aliceWethAfter = IWETH(TEST.CONFIG.weth).balanceOf(TEST.EOA.alice);
        uint256 aliceDcntEthAfter = TEST.SRC.dcntEth.balanceOf(TEST.EOA.alice);

        assertEq(aliceWethAfter, aliceWethBefore - AMOUNT, "WETH balance should decrease");
        assertEq(aliceDcntEthAfter, aliceDcntEthBefore + AMOUNT, "dcntEth balance should increase");
    }

    function test_removeLiquidityEth() public calledByAlice {
        TEST.SRC.decentEthRouter.addLiquidityEth{value: AMOUNT}();

        uint256 aliceEthBefore = TEST.EOA.alice.balance;
        uint256 aliceDcntEthBefore = TEST.SRC.dcntEth.balanceOf(TEST.EOA.alice);

        TEST.SRC.decentEthRouter.removeLiquidityEth(AMOUNT);

        uint256 aliceEthAfter = TEST.EOA.alice.balance;
        uint256 aliceDcntEthAfter = TEST.SRC.dcntEth.balanceOf(TEST.EOA.alice);

        assertEq(aliceEthAfter, aliceEthBefore + AMOUNT, "ETH balance should increase");
        assertEq(aliceDcntEthAfter, aliceDcntEthBefore - AMOUNT, "dcntEth balance should decrease");
    }

    function test_removeLiquidityWeth() public calledByAlice {
        IWETH(TEST.CONFIG.weth).approve(address(TEST.SRC.decentEthRouter), AMOUNT);
        TEST.SRC.decentEthRouter.addLiquidityWeth(AMOUNT);

        uint256 aliceWethBefore = IWETH(TEST.CONFIG.weth).balanceOf(TEST.EOA.alice);
        uint256 aliceDcntEthBefore = TEST.SRC.dcntEth.balanceOf(TEST.EOA.alice);

        TEST.SRC.decentEthRouter.removeLiquidityWeth(AMOUNT);

        uint256 aliceWethAfter = IWETH(TEST.CONFIG.weth).balanceOf(TEST.EOA.alice);
        uint256 aliceDcntEthAfter = TEST.SRC.dcntEth.balanceOf(TEST.EOA.alice);

        assertEq(aliceWethAfter, aliceWethBefore + AMOUNT, "WETH balance should increase");
        assertEq(aliceDcntEthAfter, aliceDcntEthBefore - AMOUNT, "dcntEth balance should decrease");
    }

    function test_redeemEth() public calledByAlice {
        TEST.SRC.decentEthRouter.addLiquidityEth{value: AMOUNT}();

        uint256 aliceEthBefore = TEST.EOA.alice.balance;
        uint256 aliceDcntEthBefore = TEST.SRC.dcntEth.balanceOf(TEST.EOA.alice);

        TEST.SRC.decentEthRouter.redeemEth();

        uint256 aliceEthAfter = TEST.EOA.alice.balance;
        uint256 aliceDcntEthAfter = TEST.SRC.dcntEth.balanceOf(TEST.EOA.alice);

        assertEq(aliceEthAfter, aliceEthBefore + AMOUNT, "ETH balance should increase");
        assertEq(aliceDcntEthAfter, aliceDcntEthBefore - AMOUNT, "dcntEth balance should decrease");
    }

    function test_redeemWeth() public calledByAlice {
        IWETH(TEST.CONFIG.weth).approve(address(TEST.SRC.decentEthRouter), AMOUNT);
        TEST.SRC.decentEthRouter.addLiquidityWeth(AMOUNT);

        uint256 aliceWethBefore = IWETH(TEST.CONFIG.weth).balanceOf(TEST.EOA.alice);
        uint256 aliceDcntEthBefore = TEST.SRC.dcntEth.balanceOf(TEST.EOA.alice);

        TEST.SRC.decentEthRouter.redeemWeth();

        uint256 aliceWethAfter = IWETH(TEST.CONFIG.weth).balanceOf(TEST.EOA.alice);
        uint256 aliceDcntEthAfter = TEST.SRC.dcntEth.balanceOf(TEST.EOA.alice);

        assertEq(aliceWethAfter, aliceWethBefore + AMOUNT, "WETH balance should increase");
        assertEq(aliceDcntEthAfter, aliceDcntEthBefore - AMOUNT, "dcntEth balance should decrease");
    }

    function test_redeemEthFor() public {
        vm.prank(TEST.EOA.alice);
        TEST.SRC.decentEthRouter.addLiquidityEth{value: AMOUNT}();

        uint256 aliceBalanceBefore = TEST.EOA.alice.balance;
        uint256 aliceDcntEthBefore = TEST.SRC.dcntEth.balanceOf(TEST.EOA.alice);

        vm.prank(TEST.EOA.deployer);
        TEST.SRC.decentEthRouter.redeemEthFor(TEST.EOA.alice, AMOUNT);

        uint256 aliceBalanceAfter = TEST.EOA.alice.balance;
        uint256 aliceDcntEthAfter = TEST.SRC.dcntEth.balanceOf(TEST.EOA.alice);

        assertEq(aliceBalanceAfter, aliceBalanceBefore + AMOUNT, "ETH balance should increase");
        assertEq(aliceDcntEthAfter, aliceDcntEthBefore - AMOUNT, "dcntEth balance should decrease");
    }

    function test_redeemWethFor() public {
        vm.startPrank(TEST.EOA.alice);
        IWETH(TEST.CONFIG.weth).approve(address(TEST.SRC.decentEthRouter), AMOUNT);
        TEST.SRC.decentEthRouter.addLiquidityWeth(AMOUNT);
        vm.stopPrank();

        uint256 aliceWethBefore = IWETH(TEST.CONFIG.weth).balanceOf(TEST.EOA.alice);
        uint256 aliceDcntEthBefore = TEST.SRC.dcntEth.balanceOf(TEST.EOA.alice);

        vm.prank(TEST.EOA.deployer);
        TEST.SRC.decentEthRouter.redeemWethFor(TEST.EOA.alice, AMOUNT);

        uint256 aliceWethAfter = IWETH(TEST.CONFIG.weth).balanceOf(TEST.EOA.alice);
        uint256 aliceDcntEthAfter = TEST.SRC.dcntEth.balanceOf(TEST.EOA.alice);

        assertEq(aliceWethAfter, aliceWethBefore + AMOUNT, "WETH balance should increase");
        assertEq(aliceDcntEthAfter, aliceDcntEthBefore - AMOUNT, "dcntEth balance should decrease");
    }

    function test_redeemFor_onlyAdmin() public calledByAlice {
        vm.expectRevert("Only admin");
        TEST.SRC.decentEthRouter.redeemEthFor(TEST.EOA.alice, AMOUNT);

        vm.expectRevert("Only admin");
        TEST.SRC.decentEthRouter.redeemWethFor(TEST.EOA.alice, AMOUNT);
    }

    function test_excessWithdrawal() public calledByAlice {
        vm.expectRevert("ERC20: burn amount exceeds balance");
        TEST.SRC.decentEthRouter.removeLiquidityEth(AMOUNT);
    }
}
