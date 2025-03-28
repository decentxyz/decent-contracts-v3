// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// forge contracts
import "forge-std/Script.sol";

// constants
import {Constants} from "./Constants.sol";

// eip contracts
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract BaseScript is Script, Constants {
    string constant DEPLOY_FILE = "./deployments/addresses.json";
    uint256 constant SIGNER_PRIVATE_KEY = uint256(0xC0FFEE);
    uint constant MIN_DST_GAS = 100_000;
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    function logDeployment(string memory contractName, address contractAddress) internal {
        string memory chain = vm.envString("CHAIN");
        string memory json;
        json = vm.serializeAddress(json, contractName, contractAddress);
        vm.writeJson(json, DEPLOY_FILE, string.concat(".", chain));
    }

    function _getDeployment(
        string memory chain,
        string memory contractName
    ) internal returns (address deployment) {
        string memory json = vm.readFile(DEPLOY_FILE);
        string memory path = string.concat(".", chain, ".", contractName);
        string memory label = string.concat(chain, "_", contractName);
        deployment = vm.parseJsonAddress(json, path);
        vm.label(deployment, label);
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
