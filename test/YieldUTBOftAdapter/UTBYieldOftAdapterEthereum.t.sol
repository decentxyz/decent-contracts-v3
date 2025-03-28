// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// forge contracts
import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

// test fixture
import {EthereumFixture} from "../common/EthereumFixture.sol";

// utb contracts
import {SwapInstructions, BridgeInstructions, SwapAndExecuteInstructions, FeeData, Fee} from "../../src/UTB.sol";
import {SwapParams, SwapDirection} from "../../src/CommonTypes.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {YieldOftBridgeAdapter} from "../../src/bridge_adapters/YieldOftBridgeAdapter.sol";
import {AnySwapper} from "../../src/swappers/AnySwapper.sol";

// test helpers
import {IYieldOft, IL1OftRouter, OftYieldConfig} from "../../src/interfaces/IYieldOft.sol";
import {IDecimalConversionRate} from "../../src/interfaces/IDcntEth.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SimpleSwapRouter} from '../helpers/SimpleSwapRouter.sol';

// layerzero contracts
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {IOFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

// helper contracts
import {VeryCoolCat} from "../helpers/VeryCoolCat.sol";
contract UTBYieldOftAdapterEthereum is EthereumFixture {

    OftYieldConfig yieldConfig;
    address apeETH;
    address steth;
    address l1ApeETHRouter;
    address weth;


    uint nativeFee = 0.00001 ether;
    address feeRecipient = address(0x1CE0FFEE);
    VeryCoolCat cat;
    uint64 GAS_TO_MINT = 500_000;
    address payable refund;
    BridgeInstructions bridgeInstructions;
    bytes32 public constant TRANSACTION_ID = keccak256("TRANSACTION_ID");
    AnySwapper anySwapper;
    SimpleSwapRouter swapRouter;

    function setUp() public {
        apeETH = 0xcF800F4948D16F23333508191B1B1591daF70438;
        steth = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
        weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        l1ApeETHRouter = 0x6c92CEEb09C83f1018d5BCA81d933df3eEaEd0A1;
        yieldConfig = OftYieldConfig({
            permissioned: true,
            oft: apeETH,
            // the deposited token in YieldOft
            underlying: steth,
            l1Router: l1ApeETHRouter,
            l1ChainId: 1
        });
        vm.startPrank(TEST.EOA.deployer);
        TEST.SRC.yieldOftBridgeAdapter.permissionYieldOft(apeETH, yieldConfig);
        vm.stopPrank();

        // setup
        cat = new VeryCoolCat();
        refund = payable(TEST.EOA.alice);
        deal(TEST.EOA.alice, 1000 ether);

        swapRouter = new SimpleSwapRouter();
        anySwapper = TEST.SRC.anySwapper;
        deal(weth, address(swapRouter), 100 ether);
    }
    function _roundUpDust(uint256 withDust) internal view returns (uint256 rounded) {
        uint256 rate = TEST.SRC.dcntEth.decimalConversionRate();
        uint256 withoutDust = (withDust / rate) * rate;
        rounded = withDust - withoutDust > 0
            ? withoutDust + rate
            : withoutDust;
    }

    function test_bridgeAndExecute_yield_oft_adapter_erc20_send() public {
        uint256 amount = 0.001 ether;

        vm.prank(0xFDAf8F210d52a3f8EE416ad06Ff4A0868bB649D4);
        IERC20(apeETH).transfer(TEST.EOA.alice, amount);

        vm.startPrank(TEST.EOA.deployer);
        TEST.SRC.yieldOftBridgeAdapter.registerRemoteBridgeAdapter(
            TEST.CONFIG.dstChainId, TEST.CONFIG.dstLzV2Id, 18, address(TEST.DST.yieldOftBridgeAdapter)
        );
        vm.stopPrank();


        bridgeInstructions = BridgeInstructions({
            preBridge: SwapInstructions({
                swapperId: TEST.SRC.uniSwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: apeETH,
                    amountIn: amount,
                    tokenOut: apeETH,
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
                    tokenIn: apeETH,
                    amountIn: amount,
                    tokenOut: address(0),
                    amountOut: amount,
                    dustOut: 0,
                    direction: SwapDirection.EXACT_OUT,
                    refund: refund,
                    additionalArgs: ""
                })
            }),
            bridgeId: TEST.SRC.yieldOftBridgeAdapter.ID(),
            dstChainId: TEST.CONFIG.dstChainId,
            target: TEST.EOA.alice,
            paymentOperator: TEST.EOA.alice,
            refund: refund,
            payload: abi.encodeCall(cat.mintWithErc20, (TEST.EOA.alice, apeETH, amount)),
            additionalArgs: abi.encode(apeETH, GAS_TO_MINT),
            txId: TRANSACTION_ID
        });

        (uint lzNativeFee, /*uint lzZroFee*/) = TEST.SRC.yieldOftBridgeAdapter.estimateFees(
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
        IERC20(apeETH).approve(address(TEST.SRC.utb), amount);
        // amountSentLD: 844000000000000 [8.44e14], amountReceivedLD: 844000000000000
        uint256 rate = IDecimalConversionRate(apeETH).decimalConversionRate();
        uint256 amountShares = IYieldOft(apeETH).assetsToShares(amount);
        uint256 amountLd = (amountShares / rate) * rate;
        vm.expectEmit(false, true, false, true);
        emit IOFT.OFTSent("", TEST.CONFIG.dstLzV2Id, address(TEST.SRC.yieldOftBridgeAdapter), amountLd, amountLd);
        vm.prank(TEST.EOA.alice);
        TEST.SRC.utb.bridgeAndExecute{value: nativeFee + lzNativeFee}(
            bridgeInstructions,
            feeData,
            getSignature(abi.encode(bridgeInstructions, feeData))
        );
    }

    function test_bridgeAndExecute_oft_adapter_erc20_receive() public {
        uint256 amount = 0.001 ether; // this number is < amount in pranked wallet for tranfering
        uint256 redeemAmount = IERC4626(IL1OftRouter(yieldConfig.l1Router).vault()).previewRedeem(IYieldOft(apeETH).assetsToShares(amount));
        console2.log(redeemAmount);
        // address apeCoin = 0x4d224452801ACEd8B2F0aebE155379bb5D594381;
        // address lzOftAdapter = 0x5182feDE730b31a9CF7f49C5781214B4a99F2370;

        YieldOftBridgeAdapter yieldOftBridgeAdapter = TEST.SRC.yieldOftBridgeAdapter;
        address lzEndpoint = 0x1a44076050125825900e736c501f859c50fE728c;



        bytes memory composeMsg = abi.encode(
            SwapInstructions({
                swapperId: TEST.DST.anySwapper.ID(),
                swapParams: SwapParams({
                    tokenIn: steth,
                    amountIn: amount,
                    tokenOut: weth,
                    amountOut: 6900,
                    dustOut: 0,
                    direction: SwapDirection.EXACT_OUT,
                    refund: refund,
                    additionalArgs: _encodeData(address(swapRouter),redeemAmount,6900,steth,weth,false)
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
            IYieldOft(apeETH).assetsToShares(amount),
            abi.encodePacked(OFTComposeMsgCodec.addressToBytes32(apeETH), composeMsg)
        );

        vm.prank(0xFDAf8F210d52a3f8EE416ad06Ff4A0868bB649D4);
        IERC20(apeETH).transfer(address(yieldOftBridgeAdapter), amount);

        vm.prank(lzEndpoint);

        yieldOftBridgeAdapter.lzCompose(
            apeETH,
            "",
            encodedCompose,
            address(0), /*_executor*/
            ""
        );
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
}
