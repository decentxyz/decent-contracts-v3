// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

// forge contracts
import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

// test fixture
import {BaseFixture} from "../common/BaseFixture.sol";

// utb contracts
import {BridgeInstructions} from "../../src/UTB.sol";

// helper contracts
import {VeryCoolCat} from "../helpers/VeryCoolCat.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract UTBOftAdapterSetup is BaseFixture {
    uint nativeFee = 0.00001 ether;
    address feeRecipient = address(0x1CE0FFEE);
    VeryCoolCat cat;
    uint64 GAS_TO_MINT = 500_000;
    address payable refund;
    BridgeInstructions bridgeInstructions;
    bytes32 public constant TRANSACTION_ID = keccak256("TRANSACTION_ID");

    function setUp() public {
        cat = new VeryCoolCat();
        refund = payable(TEST.EOA.alice);
        deal(TEST.EOA.alice, 1000 ether);
        deal(address(TEST.SRC.mockOft), TEST.EOA.alice, 1000 ether);
    }

    function _roundUpDust(uint256 withDust) internal view returns (uint256 rounded) {
        uint256 rate = TEST.SRC.dcntEth.decimalConversionRate();
        uint256 withoutDust = (withDust / rate) * rate;
        rounded = withDust - withoutDust > 0
            ? withoutDust + rate
            : withoutDust;
    }
}
