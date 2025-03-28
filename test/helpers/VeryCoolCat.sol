// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract VeryCoolCat is ERC721 {
    IERC20 usdc;
    IERC20 weth;
    IERC20 sgEth;
    IERC20 usdt;
    uint public price = 6.9e6;
    uint public wethPrice = 0.123456789123456789 ether;
    uint public ethPrice = 0.123456789123456789 ether;
    uint public sgEthPrice = 0.123456789123456789 ether;
    uint public polygonPrice = 10 ether;
    uint public usdtPrice = 1e6;
    uint public executionFee = 0.000123 ether;
    uint count = 0;

    constructor() ERC721("cool cat", "cool") {}

    function setWeth(address _addr) public {
        weth = IERC20(_addr);
    }

    function setUsdc(address _addr) public {
        usdc = IERC20(_addr);
    }

    function setSgEth(address _addr) public {
        sgEth = IERC20(_addr);
    }

    function setUsdt(address _addr) public {
        usdt = IERC20(_addr);
    }

    function tokenURI(uint256 /*id*/) public pure override returns (string memory) {
        return "";
    }

    function _mint(address to) private {
        count += 1;
        super._mint(to, count);
    }

    function mintWithUsdc(address to) public {
        usdc.transferFrom(msg.sender, address(this), price);
        _mint(to);
    }

    function mintWithUsdt(address to) public {
        SafeERC20.safeTransferFrom(usdt, msg.sender, address(this), usdtPrice);
        _mint(to);
    }

    function mintWithWeth(address to) public {
        weth.transferFrom(msg.sender, address(this), wethPrice);
        _mint(to);
    }

    function mintWithWethPlusFee(address to) public payable {
        require(msg.value == executionFee, 'invalid execution fee');
        weth.transferFrom(msg.sender, address(this), wethPrice);
        _mint(to);
    }

    function mintWithSgEth(address to) public {
        weth.transferFrom(msg.sender, address(this), wethPrice);
        _mint(to);
    }

    function mintWithEth(address to) public payable {
        require(msg.value == ethPrice, 'invalid eth price');
        _mint(to);
    }

    function mintWithPolygon(address to) public payable {
        require(msg.value == polygonPrice);
        _mint(to);
    }

    function mintWithErc20(address to, address erc20, uint256 required) public {
        IERC20(erc20).transferFrom(msg.sender, address(this), required);
        _mint(to);
    }

    receive() external payable {}

    fallback() external payable {}
}
