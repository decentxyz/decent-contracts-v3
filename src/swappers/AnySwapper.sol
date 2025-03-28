// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {Swapper} from './Swapper.sol';
import {SwapParams, SwapDirection} from "../CommonTypes.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISwapper} from "../UTB.sol";

contract AnySwapper is Swapper {

    uint8 public constant ID = 1;

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
            amountOut = _swapExactOut(swapParams);
        }
    }

    function _swapExactIn(
        SwapParams memory swapParams
    ) private returns (uint256 amountOut) {
        (
            address router,
            bytes memory swapPayload
        ) = abi.decode(swapParams.additionalArgs, (address, bytes));

        address tokenOut = _getTokenOrWrapped(swapParams.tokenOut);
        uint256 startingBalanceIn = IERC20(swapParams.tokenIn).balanceOf(address(this));
        uint256 startingBalanceOut = IERC20(tokenOut).balanceOf(address(this));

        swapParams = _receiveAndWrapIfNeeded(swapParams);
        SafeERC20.forceApprove(IERC20(swapParams.tokenIn), router, swapParams.amountIn);

        (bool success, ) = router.call(swapPayload);
        if (!success) revert SwapFailed();

        uint256 swapBalanceIn = IERC20(swapParams.tokenIn).balanceOf(address(this));
        uint256 swapBalanceOut = IERC20(tokenOut).balanceOf(address(this));
        uint256 amountIn = swapParams.amountIn - (swapBalanceIn - startingBalanceIn);
        amountOut = swapBalanceOut - startingBalanceOut;

        _sendToUtb(tokenOut, amountOut);

        _refundUser(
            swapParams.refund,
            swapParams.tokenIn,
            swapParams.amountIn - amountIn
        );
    }

    function _swapExactOut(
        SwapParams memory swapParams
    ) private returns (uint256 amountOut) {
        (
            address router,
            bytes memory swapPayload
        ) = abi.decode(swapParams.additionalArgs, (address, bytes));

        address tokenOut = _getTokenOrWrapped(swapParams.tokenOut);
        uint256 startingBalanceIn = IERC20(swapParams.tokenIn).balanceOf(address(this));
        uint256 startingBalanceOut = IERC20(tokenOut).balanceOf(address(this));

        swapParams = _receiveAndWrapIfNeeded(swapParams);
        SafeERC20.forceApprove(IERC20(swapParams.tokenIn), router, swapParams.amountIn);

        (bool success, ) = router.call(swapPayload);
        if (!success) revert SwapFailed();

        uint256 swapBalanceIn = IERC20(swapParams.tokenIn).balanceOf(address(this));
        uint256 swapBalanceOut = IERC20(tokenOut).balanceOf(address(this));
        uint256 amountIn = swapParams.amountIn - (swapBalanceIn - startingBalanceIn);
        amountOut = swapBalanceOut - startingBalanceOut;

        _sendToUtb(tokenOut, amountOut);

        _refundUser(
            swapParams.refund,
            swapParams.tokenIn,
            swapParams.amountIn - amountIn
        );
    }

    function _getTokenOrWrapped(address _token) internal view returns (address token) {
        return _token != address(0) ? _token : wrapped;
    }
}
