// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {UTBOwned} from "../UTBOwned.sol";
import {SwapDirection, SwapParams} from "../CommonTypes.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {ISwapper} from "../UTB.sol";

abstract contract Swapper is UTBOwned, ISwapper {

    error SwapFailed();

    address payable public wrapped;

    function swap(
        SwapParams memory swapParams
    ) external virtual returns (
        address tokenOut,
        uint256 amountOut
    );

    function setWrapped(address payable _wrapped) public onlyAdmin {
        wrapped = _wrapped;
    }

    function _refundUser(address user, address token, uint amount) internal virtual {
        if ( amount > 0 ) {
            SafeERC20.safeTransfer(IERC20(token), user, amount);
        }
    }

    function _sendToUtb(
        address token,
        uint amount
    ) internal virtual {
        if (token == address(0)) {
            token = wrapped;
        }
        SafeERC20.safeTransfer(IERC20(token), utb, amount);
    }

    function _receiveAndWrapIfNeeded(
        SwapParams memory swapParams
    ) internal virtual returns (SwapParams memory _swapParams) {
        if (swapParams.tokenIn != address(0)) {
            SafeERC20.safeTransferFrom(
                IERC20(swapParams.tokenIn),
                msg.sender,
                address(this),
                swapParams.amountIn
            );
            return swapParams;
        }
        swapParams.tokenIn = wrapped;
        IWETH(wrapped).deposit{value: swapParams.amountIn}();
        return swapParams;
    }
}
