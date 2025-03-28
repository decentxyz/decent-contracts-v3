// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// utb contracts
import {OftBridgeAdapter} from "../src/bridge_adapters/OftBridgeAdapter.sol";
import {YieldOftBridgeAdapter} from "../src/bridge_adapters/YieldOftBridgeAdapter.sol";
import {OftYieldConfig} from "../src/interfaces/IYieldOft.sol";

// base script
import {BaseScript} from "./BaseScript.s.sol";

contract OftTasks is BaseScript {
    function permissionOft(
        address _oftBridgeAdapter,
        address _oft,
        address _lzOftAdapter
    ) internal {
        OftBridgeAdapter oftBridgeAdapter = OftBridgeAdapter(payable(_oftBridgeAdapter));
        oftBridgeAdapter.permissionOft(_oft, _lzOftAdapter);
    }

    function permissionYieldOft(
        address _yieldOftBridgeAdapter,
        address _oft,
        OftYieldConfig memory _config
    ) internal {
        YieldOftBridgeAdapter yieldOftBridgeAdapter = YieldOftBridgeAdapter(payable(_yieldOftBridgeAdapter));
        yieldOftBridgeAdapter.permissionYieldOft(_oft, _config);
    }

    function disallowOft(
        address _oftBridgeAdapter,
        address _oft
    ) internal {
        OftBridgeAdapter oftBridgeAdapter = OftBridgeAdapter(payable(_oftBridgeAdapter));
        oftBridgeAdapter.disallowOft(_oft);
    }

    function disallowYieldOft(
        address _yieldOftBridgeAdapter,
        address _oft
    ) internal {
        YieldOftBridgeAdapter yieldOftBridgeAdapter = YieldOftBridgeAdapter(payable(_yieldOftBridgeAdapter));
        yieldOftBridgeAdapter.disallowYieldOft(_oft);
    }
}

contract PermissionOft is OftTasks {
    function run() external {
        string memory chain = vm.envString("CHAIN");
        address oft = vm.envAddress("OFT");
        address lzOftAdapter = vm.envAddress("OFT_ADAPTER");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        address oftBridgeAdapter = _getDeployment(chain, "OftBridgeAdapter");

        vm.startBroadcast(account);

        permissionOft(oftBridgeAdapter, oft, lzOftAdapter);

        vm.stopBroadcast();
    }
}

contract DisallowOft is OftTasks {
    function run() external {
        string memory chain = vm.envString("CHAIN");
        address oft = vm.envAddress("OFT");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        address oftBridgeAdapter = _getDeployment(chain, "OftBridgeAdapter");

        vm.startBroadcast(account);

        disallowOft(oftBridgeAdapter, oft);

        vm.stopBroadcast();
    }
}

contract PermissionYieldOft is OftTasks {
    function run() external {
        string memory chain = vm.envString("CHAIN");
        address oft = vm.envAddress("OFT");
        address underlying = vm.envAddress("UNDERLYING");
        address l1Router = vm.envAddress("L1_ROUTER");
        uint256 l1ChainId = vm.envUint("L1_CHAIN_ID");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        address yieldOftBridgeAdapter = _getDeployment(chain, "YieldOftBridgeAdapter");

        OftYieldConfig memory oftYieldConfig = OftYieldConfig({
            permissioned: true,
            oft: oft,
            underlying: underlying,
            l1Router: l1Router,
            l1ChainId: l1ChainId
        });

        vm.startBroadcast(account);

        permissionYieldOft(yieldOftBridgeAdapter, oft, oftYieldConfig);

        vm.stopBroadcast();
    }
}

contract DisallowYieldOft is OftTasks {
    function run() external {
        string memory chain = vm.envString("CHAIN");
        address oft = vm.envAddress("OFT");
        uint256 account = vm.envUint(vm.envString("PRIVATE_KEY"));

        address yieldOftBridgeAdapter = _getDeployment(chain, "YieldOftBridgeAdapter");

        vm.startBroadcast(account);

        disallowYieldOft(yieldOftBridgeAdapter, oft);

        vm.stopBroadcast();
    }
}
