// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {SwapParams} from "../CommonTypes.sol";

interface ISwapper {
    error RouterNotSet();

    function ID() external returns (uint8);

    function swap(
      SwapParams memory swapParams
    ) external returns (
      address tokenOut, uint256 amountOut
    );
}
