// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// bridge contracts
import {DecentBridgeExecutor} from "../src/DecentBridgeExecutor.sol";
import {DecentEthRouter} from "../src/DecentEthRouter.sol";
import {DcntEth} from "../src/DcntEth.sol";

// base script
import {BaseScript} from "./BaseScript.s.sol";

// eip contracts
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract BridgeTasks is BaseScript {
    function _deployBridge() internal returns (
        DecentBridgeExecutor decentBridgeExecutor,
        DecentEthRouter decentEthRouter,
        DcntEth dcntEth
    ) {
        string memory chain = vm.envString("CHAIN");
        address weth = wethLookup[chain];
        bool isGasEth = gasEthLookup[chain];
        address lzEndpoint = address(lzV2EndpointLookup[chain]);

        decentBridgeExecutor = new DecentBridgeExecutor(weth, isGasEth);
        decentEthRouter = new DecentEthRouter(payable(weth), isGasEth, address(decentBridgeExecutor));
        dcntEth = new DcntEth(lzEndpoint);
    }

    function _configureBridge(
        address _dcntEth,
        address _decentEthRouter,
        address _decentBridgeExecutor
    ) internal {
        DcntEth dcntEth = DcntEth(_dcntEth);
        DecentEthRouter decentEthRouter = DecentEthRouter(payable(_decentEthRouter));
        DecentBridgeExecutor decentBridgeExecutor = DecentBridgeExecutor(payable(_decentBridgeExecutor));

        dcntEth.setRouter(_decentEthRouter);
        decentEthRouter.registerDcntEth(_dcntEth);
        decentBridgeExecutor.setOperator(_decentEthRouter);
    }

    function _connectDecentBridge(
        address _srcDcntEth,
        address dstDcntEth,
        address _srcDecentEthRouter,
        address dstDecentEthRouter,
        uint32 dstLzId
    ) internal {
        DcntEth srcDcntEth = DcntEth(_srcDcntEth);
        DecentEthRouter srcDecentEthRouter = DecentEthRouter(payable(_srcDecentEthRouter));

        srcDecentEthRouter.addDestinationBridge(dstLzId, dstDecentEthRouter);
        srcDcntEth.setPeer(dstLzId, addressToBytes32(dstDcntEth));
    }

    function addLiquidity(address _decentEthRouter, uint256 amount) public {
        string memory chain = vm.envString("CHAIN");
        DecentEthRouter decentEthRouter = DecentEthRouter(payable(_decentEthRouter));

        if (gasEthLookup[chain]) {
            decentEthRouter.addLiquidityEth{value: amount}();
        } else {
            IERC20(wethLookup[chain]).approve(address(decentEthRouter), amount);
            decentEthRouter.addLiquidityWeth(amount);
        }
    }

    function removeLiquidity(address _decentEthRouter, uint256 amount) public {
        string memory chain = vm.envString("CHAIN");
        DecentEthRouter decentEthRouter = DecentEthRouter(payable(_decentEthRouter));

        if (gasEthLookup[chain]) {
            decentEthRouter.removeLiquidityEth(amount);
        } else {
            decentEthRouter.removeLiquidityWeth(amount);
        }
    }

    function bridge(address _decentEthRouter, address to, uint256 amount, uint32 dstLzId) public {
        uint64 gas = 120e3;
        DecentEthRouter decentEthRouter = DecentEthRouter(payable(_decentEthRouter));

        (uint nativeFee, uint zroFee) = decentEthRouter.estimateSendAndCallFee(
            0,
            dstLzId,
            to,
            msg.sender,
            amount,
            gas,
            true,
            ""
        );

        decentEthRouter.bridge{value: nativeFee + zroFee + amount}(
            dstLzId,
            to,
            msg.sender,
            amount,
            gas,
            true
        );
    }
}

contract AddLiquidity is BridgeTasks {
    function run() external {
        string memory chain = vm.envString("CHAIN");
        uint256 amount = vm.envUint("AMOUNT");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        vm.startBroadcast(account);

        address decentEthRouter = _getDeployment(chain, "DecentEthRouter");
        addLiquidity(decentEthRouter, amount);

        vm.stopBroadcast();
    }
}

contract RemoveLiquidity is BridgeTasks {
    function run() external {
        string memory chain = vm.envString("CHAIN");
        uint256 amount = vm.envUint("AMOUNT");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        vm.startBroadcast(account);

        address decentEthRouter = _getDeployment(chain, "DecentEthRouter");
        removeLiquidity(decentEthRouter, amount);

        vm.stopBroadcast();
    }
}

contract Bridge is BridgeTasks {
    function run() public {
        uint256 amount = vm.envUint("AMOUNT");
        string memory src = vm.envString("SRC");
        string memory dst = vm.envString("DST");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        address decentEthRouter = _getDeployment(src, "DecentEthRouter");
        address to = vm.addr(account);
        uint32 dstLzId = lzV2IdLookup[dst];

        vm.startBroadcast(account);

        bridge(decentEthRouter, to, amount, dstLzId);

        vm.stopBroadcast();
    }
}
