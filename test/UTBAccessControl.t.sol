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

// helper contracts
import {VeryCoolCat} from "./helpers/VeryCoolCat.sol";

contract UTBAccessControl is Test, EthereumFixture {

    function testUtbReceiveFromBridge() public {
        SwapParams memory swapParams = SwapParams({
            tokenIn: address(0),
            amountIn: 1 ether,
            tokenOut: address(0),
            amountOut: 1 ether,
            dustOut: 0,
            direction: SwapDirection.EXACT_OUT,
            refund: address(0),
            additionalArgs: ""
        });

        uint8 swapperId = TEST.SRC.uniSwapper.ID();

        SwapInstructions memory swapInstructions = SwapInstructions({
            swapperId: swapperId,
            swapParams: swapParams
        });

        vm.expectRevert(bytes4(keccak256("OnlyBridgeAdapter()")));

        TEST.SRC.utb.receiveFromBridge(
            swapInstructions,
            address(0),
            address(0),
            "",
            payable(address(0)),
            swapperId,
            ""
        );
    }

    function testUtbSetExecutor() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.utb.setExecutor(address(0));
        vm.stopPrank();
    }

    function testUtbSetWrapped() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.utb.setWrapped(payable(address(0)));
        vm.stopPrank();
    }

    function testUtbSetFeeManager() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.utb.setFeeManager(address(0));
        vm.stopPrank();
    }

    function testUtbRegisterSwapper() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.utb.registerSwapper(address(0));
        vm.stopPrank();
    }

    function testUtbRegisterBridge() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.utb.registerBridge(address(0));
        vm.stopPrank();
    }

    function testUtbWithdraw() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert("Only admin");
        TEST.SRC.utb.withdraw(address(0), 1 ether);
        vm.stopPrank();
    }

    function testUtbWithdrawERC20() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert("Only admin");
        TEST.SRC.utb.withdrawERC20(address(TEST.CONFIG.weth), TEST.EOA.alice, 1 ether);
        vm.stopPrank();
    }

    function testUtbExecutorExecute() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only operator'));
        TEST.SRC.utbExecutor.execute(
            address(0),
            address(0),
            "",
            address(0),
            0,
            payable(address(0)),
            0
        );
        vm.stopPrank();
    }

    function testUtbExecutorDisallow() public {
        address disallowed = address(0xC0FFEE);

        vm.prank(TEST.EOA.deployer);
        TEST.SRC.utbExecutor.disallow(disallowed);

        vm.prank(address(TEST.SRC.utb));
        vm.expectRevert(bytes4(keccak256("Disallowed()")));

        TEST.SRC.utbExecutor.execute(
            disallowed,
            disallowed,
            "",
            address(0),
            0,
            address(0),
            0
        );
    }

    function testUtbReceive() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes4(keccak256("OnlyWrapped()")));
        (address(TEST.SRC.utb).call{value: 1 ether}(""));
        vm.stopPrank();

        vm.startPrank(TEST.CONFIG.weth);
        (address(TEST.SRC.utb).call{value: 1 ether}(""));
        assertEq(address(TEST.SRC.utb).balance, 1 ether);
        vm.stopPrank();
    }

    function testUniSwapperSetWrapped() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.uniSwapper.setWrapped(payable(address(0)));
        vm.stopPrank();
    }

    function testUniSwapperSetRouter() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.uniSwapper.setRouter(address(0));
        vm.stopPrank();
    }

    function testUniSwapperSwap() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only utb'));
        TEST.SRC.uniSwapper.swap(
            SwapParams({
                tokenIn: address(0),
                amountIn: 1 ether,
                tokenOut: address(0),
                amountOut: 1 ether,
                dustOut: 0,
                direction: SwapDirection.EXACT_OUT,
                refund: address(0),
                additionalArgs: ""
            })
        );
        vm.stopPrank();
    }

    function testAnySwapperSetWrapped() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.anySwapper.setWrapped(payable(address(0)));
        vm.stopPrank();
    }

    function testAnySwapperSwap() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only utb'));
        TEST.SRC.anySwapper.swap(
            SwapParams({
                tokenIn: address(0),
                amountIn: 1 ether,
                tokenOut: address(0),
                amountOut: 1 ether,
                dustOut: 0,
                direction: SwapDirection.EXACT_OUT,
                refund: address(0),
                additionalArgs: ""
            })
        );
        vm.stopPrank();
    }

    function testDecentBridgeAdapterSetRouter() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.decentBridgeAdapter.setRouter(address(0));
        vm.stopPrank();
    }

    function testDecentBridgeAdapterRegisterRemoteBridgeAdapter() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.decentBridgeAdapter.registerRemoteBridgeAdapter(0, 0, 0, address(0));
        vm.stopPrank();
    }

    function testStargateBridgeAdapterSetStargateComposer() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.stargateBridgeAdapter.setStargateComposer(address(0));
        vm.stopPrank();
    }

    function testStargetBridgeAdapterRegisterRemoteBridgeAdapter() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.stargateBridgeAdapter.registerRemoteBridgeAdapter(0, 0, 0, address(0));
        vm.stopPrank();
    }

    function testDcntEthSetRouter() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.dcntEth.setRouter(address(0));
        vm.stopPrank();
    }

    function testDcntEthMint() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only router'));
        TEST.SRC.dcntEth.mint(address(0), 0);
        vm.stopPrank();
    }

    function testDcntEthBurn() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only router'));
        TEST.SRC.dcntEth.burn(address(0), 0);
        vm.stopPrank();
    }

    function testDcntEthMintByAdmin() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.dcntEth.mintByAdmin(address(0), 0);
        vm.stopPrank();
    }

    function testDcntEthBurnByAdmin() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.dcntEth.burnByAdmin(address(0), 0);
        vm.stopPrank();
    }

    function testDecentEthRouterRegisterDcntEth() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.decentEthRouter.registerDcntEth(address(0));
        vm.stopPrank();
    }

    function testDecentEthRouterAddDestinationBridge() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.decentEthRouter.addDestinationBridge(0, address(0));
        vm.stopPrank();
    }

    function testDecentEthRouterSetRequireOperator() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only admin'));
        TEST.SRC.decentEthRouter.setRequireOperator(false);
        vm.stopPrank();
    }

    function testDecentEthRouterLzCompose() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes4(keccak256("OnlyLzEndpoint()")));
        TEST.DST.decentEthRouter.lzCompose(address(0), "", "", address(0), "");
        vm.stopPrank();

        vm.startPrank(endpoints[TEST.LZ.dstId]);
        vm.expectRevert(bytes4(keccak256("OnlyDcntEth()")));
        TEST.DST.decentEthRouter.lzCompose(address(0), "", "", address(0), "");
        vm.stopPrank();
    }

    function testDecentEthRouterReceive() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes4(keccak256("OnlyWeth()")));
        (address(TEST.SRC.decentEthRouter).call{value: 1 ether}(""));
        vm.stopPrank();

        vm.startPrank(TEST.CONFIG.weth);
        (address(TEST.SRC.decentEthRouter).call{value: 1 ether}(""));
        assertEq(address(TEST.SRC.decentEthRouter).balance, 1 ether);
        vm.stopPrank();
    }

    function testDecentBridgeExecutorExecute() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes('Only operator'));
        TEST.SRC.decentBridgeExecutor.execute(
            address(0),
            address(0),
            true,
            0,
            ""
        );
        vm.stopPrank();
    }

    function testDecentBridgeExecutorReceive() public {
        vm.startPrank(TEST.EOA.alice);
        vm.expectRevert(bytes4(keccak256("OnlyWeth()")));
        (address(TEST.SRC.decentBridgeExecutor).call{value: 1 ether}(""));
        vm.stopPrank();

        vm.startPrank(TEST.CONFIG.weth);
        (address(TEST.SRC.decentBridgeExecutor).call{value: 1 ether}(""));
        assertEq(address(TEST.SRC.decentBridgeExecutor).balance, 1 ether);
        vm.stopPrank();
    }

    function testDecentBridgeExecutorDisallow() public {
        address disallowed = address(0xC0FFEE);

        vm.prank(TEST.EOA.deployer);
        TEST.SRC.decentBridgeExecutor.disallow(disallowed);

        vm.prank(address(TEST.SRC.decentEthRouter));
        vm.expectRevert(bytes4(keccak256("Disallowed()")));
        TEST.SRC.decentBridgeExecutor.execute(
            address(0),
            disallowed,
            true,
            0,
            ""
        );
    }

    function testRevertSwapAndExecuteIsNotActive() public {
        vm.startPrank(TEST.EOA.deployer);
        TEST.SRC.utb.toggleActive();
        vm.stopPrank();

        SwapAndExecuteInstructions memory swapAndExecInstructions;
        FeeData memory feeData;

        vm.expectRevert(bytes4(keccak256("UTBPaused()")));

        TEST.SRC.utb.swapAndExecute(
            swapAndExecInstructions,
            feeData,
            getSignature(abi.encode(swapAndExecInstructions, feeData))
        );
    }

    function testRevertBridgeAndExecuteIsNotActive() public {
        vm.startPrank(TEST.EOA.deployer);
        TEST.SRC.utb.toggleActive();
        vm.stopPrank();

        BridgeInstructions memory bridgeInstructions;
        FeeData memory feeData;

        vm.expectRevert(bytes4(keccak256("UTBPaused()")));

        TEST.SRC.utb.bridgeAndExecute(
            bridgeInstructions,
            feeData,
            getSignature(abi.encode(bridgeInstructions, feeData))
        );
    }
}
