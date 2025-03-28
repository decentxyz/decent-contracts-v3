// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// forge contracts
import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

// test fixture
import {EthereumFixture} from "../common/EthereumFixture.sol";
import {UTBOftAdapterSetup} from "./UTBOftAdapterSetup.sol";

// utb contracts
import {SwapInstructions, BridgeInstructions, FeeData, Fee} from "../../src/UTB.sol";
import {SwapParams, SwapDirection} from "../../src/CommonTypes.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BaseAdapter} from "../../src/bridge_adapters/BaseAdapter.sol";
import {OftBridgeAdapter} from "../../src/bridge_adapters/OftBridgeAdapter.sol";

// layerzero contracts
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {IOFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

// openzep contracts
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract UTBOftAdapterMock is UTBOftAdapterSetup, EthereumFixture {
    using OptionsBuilder for bytes;

    function test_bridgeAndExecute_example() public {
        uint256 amountHP = cat.ethPrice();
        uint256 amount = _roundUpDust(amountHP);

        bridgeInstructions = BridgeInstructions({
            preBridge: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: address(TEST.SRC.mockOft),
                    amountIn: amount,
                    tokenOut: address(TEST.SRC.mockOft),
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
                    tokenIn: address(TEST.DST.mockOft),
                    amountIn: amount,
                    tokenOut: address(TEST.DST.mockOft),
                    amountOut: amount,
                    dustOut: amount - amountHP,
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
            payload: abi.encodeCall(cat.mintWithErc20, (TEST.EOA.alice, address(TEST.DST.mockOft), amountHP)),
            additionalArgs: abi.encode(address(TEST.SRC.mockOft), GAS_TO_MINT, address(TEST.SRC.mockOft)),
            txId: TRANSACTION_ID
        });

        (uint lzNativeFee, /*uint lzZroFee*/) = TEST.SRC.oftBridgeAdapter.estimateFees(
            IBridgeAdapter.BridgeCall({
                amount: amount,
                postBridge: bridgeInstructions.postBridge,
                dstChainId: bridgeInstructions.dstChainId,
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
        IERC20(TEST.SRC.mockOft).approve(address(TEST.SRC.utb), amount);

        vm.prank(TEST.EOA.alice);
        TEST.SRC.utb.bridgeAndExecute{value: nativeFee + lzNativeFee}(
            bridgeInstructions,
            feeData,
            getSignature(abi.encode(bridgeInstructions, feeData))
        );

        bytes32 guid = getNextInflightPacketGuid(
            TEST.LZ.dstId,
            addressToBytes32(address(TEST.DST.mockOft))
        );

        verifyPackets(
            TEST.LZ.dstId,
            addressToBytes32(address(TEST.DST.mockOft))
        );

        bytes memory options = OptionsBuilder.newOptions()
            .addExecutorLzReceiveOption(TEST.DST.oftBridgeAdapter.gasForRelay(), 0)
            .addExecutorLzComposeOption(0, GAS_TO_MINT, 0);

        // questions from here (start) to
        bytes memory message = OFTComposeMsgCodec.encode(
            1, // nonce
            TEST.LZ.srcId,
            amount,
            abi.encodePacked(
                addressToBytes32(address(TEST.SRC.oftBridgeAdapter)),
                abi.encode(
                    bridgeInstructions.postBridge,
                    bridgeInstructions.target,
                    bridgeInstructions.paymentOperator,
                    bridgeInstructions.payload,
                    bridgeInstructions.refund,
                    bridgeInstructions.txId
                )
            )
        );

        this.lzCompose(
            TEST.LZ.dstId,
            address(TEST.DST.mockOft),
            options,
            guid,
            address(TEST.DST.oftBridgeAdapter),
            message
        );
        // here (end)

        uint nativeBalance = address(feeRecipient).balance;
        assertEq(nativeBalance, nativeFee);

        uint nftBalance = cat.balanceOf(TEST.EOA.alice);
        assertEq(nftBalance, 1);
    }

    function test_registerRemoteBridgeAdapter() public {
        uint256 dstChainId = 1;
        uint32 dstLzId = 2;
        uint8 decimals = 18;
        address remoteAdapter = makeAddr("RemoteAdapter");

        vm.prank(TEST.EOA.deployer);
        TEST.SRC.oftBridgeAdapter.registerRemoteBridgeAdapter(dstChainId, dstLzId, decimals, remoteAdapter);

        assertEq(TEST.SRC.oftBridgeAdapter.chainIdLookup(dstLzId), dstChainId);
        assertEq(TEST.SRC.oftBridgeAdapter.lzIdLookup(dstChainId), dstLzId);
        assertEq(TEST.SRC.oftBridgeAdapter.destinationBridgeAdapter(dstChainId), remoteAdapter);
        assertEq(TEST.SRC.oftBridgeAdapter.remoteDecimals(dstChainId), decimals);
    }

    function test_registerRemoteBridgeAdapter_onlyAdmin() public {
        vm.expectRevert("Only admin");
        TEST.SRC.oftBridgeAdapter.registerRemoteBridgeAdapter(0, 0, 0, address(0));
    }

    function test_setGasForRelay() public {
        uint128 gasForRelay = 1234567890;
        uint128 gasForRelayDefault = TEST.SRC.oftBridgeAdapter.gasForRelay();
        assertNotEq(gasForRelayDefault, 0);
        assertNotEq(gasForRelayDefault, gasForRelay);

        vm.expectEmit(false, false, false, true);
        emit BaseAdapter.SetGasForRelay(gasForRelayDefault, gasForRelay);

        vm.prank(TEST.EOA.deployer);
        TEST.SRC.oftBridgeAdapter.setGasForRelay(gasForRelay);
        assertEq(TEST.SRC.oftBridgeAdapter.gasForRelay(), gasForRelay);
    }

    function test_setGasForRelay_onlyAdmin() public {
        vm.expectRevert("Only admin");
        TEST.SRC.oftBridgeAdapter.setGasForRelay(0);
    }

    function test_getBridgeToken() public {
        address bridgeToken = makeAddr("BridgeToken");
        assertEq(TEST.SRC.oftBridgeAdapter.getBridgeToken(abi.encode(bridgeToken)), bridgeToken);
    }

    function test_permissionOft() public {
        address mockOft = address(TEST.SRC.mockOft);

        vm.prank(TEST.EOA.deployer);
        TEST.SRC.oftBridgeAdapter.permissionOft(mockOft, mockOft);

        (bool permissioned, address oft) = TEST.SRC.oftBridgeAdapter.oftLookup(mockOft);
        assertEq(mockOft, oft);
        assertEq(permissioned, true);
    }

    function test_permissionOft_onlyAdmin() public {
        vm.expectRevert("Only admin");
        TEST.SRC.oftBridgeAdapter.permissionOft(address(0), address(0));
    }


    function test_disallowOft() public {
        address mockOft = address(TEST.SRC.mockOft);

        vm.prank(TEST.EOA.deployer);
        TEST.SRC.oftBridgeAdapter.permissionOft(mockOft, mockOft);

        {
            (bool permissioned, address oft) = TEST.SRC.oftBridgeAdapter.oftLookup(mockOft);
            assertEq(mockOft, oft);
            assertEq(permissioned, true);
        }

        vm.prank(TEST.EOA.deployer);
        TEST.SRC.oftBridgeAdapter.disallowOft(mockOft);

        {
            (bool permissioned, ) = TEST.SRC.oftBridgeAdapter.oftLookup(mockOft);
            assertEq(permissioned, false);
        }
    }

    function test_disallowOft_onlyAdmin() public {
        vm.expectRevert("Only admin");
        TEST.SRC.oftBridgeAdapter.disallowOft(address(0));
    }
}
