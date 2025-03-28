// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IOFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {IOAppCore} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppCore.sol";

interface IDcntEth is IOFT, IOAppCore, IERC20 {

    event SetRouter(address router);

    function setRouter(address _router) external;

    function mint(address _to, uint256 _amount) external;

    function burn(address _from, uint256 _amount) external;

    function mintByAdmin(address _to, uint256 _amount) external;

    function burnByAdmin(address _from, uint256 _amount) external;
}

interface IDecimalConversionRate {
    function decimalConversionRate() external view returns (uint256);
}
