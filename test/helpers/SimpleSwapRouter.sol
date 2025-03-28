// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract SimpleSwapRouter {
  function swapExactIn(uint256 amountIn, uint256 amountOut, address tokenA, address tokenB, address to) public returns (uint256) {
    IERC20(tokenA).transferFrom(msg.sender, address(this), amountIn);
    IERC20(tokenB).transfer(to, amountOut);
    return amountOut;
  }

  function swapExactOut(uint256 amountIn, uint256 amountOut, address tokenA, address tokenB, address to) public returns (uint256){
    IERC20(tokenA).transferFrom(msg.sender, address(this), amountIn);
    IERC20(tokenB).transfer(to, amountOut);
    return amountIn;
  }
}
