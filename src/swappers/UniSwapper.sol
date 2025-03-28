// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {SwapParams, SwapDirection} from "../CommonTypes.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {Swapper} from "../../src/swappers/Swapper.sol";
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";

contract UniSwapper is Swapper {

    uint8 public constant ID = 0;
    address public uniswap_router;

    function setRouter(address _router) public onlyAdmin {
        uniswap_router = _router;
    }

    function swap(
        SwapParams memory swapParams
    ) external override onlyUtb returns (
        address tokenOut,
        uint256 amountOut
    ) {
        tokenOut = swapParams.tokenOut;

        if (swapParams.direction == SwapDirection.EXACT_IN) {
            amountOut = _swapExactIn(swapParams);
        } else {
            _swapExactOut(swapParams);
            amountOut = swapParams.amountOut;
        }
    }

    modifier routerIsSet() {
        if (uniswap_router == address(0)) revert RouterNotSet();
        _;
    }

    function _swapExactIn(
        SwapParams memory swapParams // SwapParams is a struct
    ) private routerIsSet returns (uint256 amountOut) {
        swapParams = _receiveAndWrapIfNeeded(swapParams);

        IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter
            .ExactInputParams({
                path: swapParams.additionalArgs,
                recipient: address(this),
                amountIn: swapParams.amountIn,
                amountOutMinimum: swapParams.amountOut
            });

        SafeERC20.forceApprove(IERC20(swapParams.tokenIn), uniswap_router, swapParams.amountIn);
        amountOut = IV3SwapRouter(uniswap_router).exactInput(params);

        _sendToUtb(swapParams.tokenOut, amountOut);
    }

    function _swapExactOut(
        SwapParams memory swapParams
    ) private routerIsSet returns (uint256 amountIn) {
        swapParams = _receiveAndWrapIfNeeded(swapParams);

        IV3SwapRouter.ExactOutputParams memory params = IV3SwapRouter
            .ExactOutputParams({
                path: swapParams.additionalArgs,
                recipient: address(this),
                //deadline: block.timestamp,
                amountOut: swapParams.amountOut,
                amountInMaximum: swapParams.amountIn
            });

        SafeERC20.forceApprove(IERC20(swapParams.tokenIn), uniswap_router, swapParams.amountIn);
        amountIn = IV3SwapRouter(uniswap_router).exactOutput(params);

        _refundUser(
            swapParams.refund,
            swapParams.tokenIn,
            params.amountInMaximum - amountIn
        );

        _sendToUtb(swapParams.tokenOut, swapParams.amountOut);
    }
}
