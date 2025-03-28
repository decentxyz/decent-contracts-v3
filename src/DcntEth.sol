// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Roles} from "./utils/Roles.sol";
import {Withdrawable} from "./utils/Withdrawable.sol";
import {IDcntEth} from "./interfaces/IDcntEth.sol";
import {AccessControlDefaultAdminRules} from "@openzeppelin/contracts/access/AccessControlDefaultAdminRules.sol";

contract DcntEth is IDcntEth, OFT, Roles, Withdrawable {
    address public router;

    modifier onlyRouter() {
        require(msg.sender == router, "Only router");
        _;
    }

    constructor(
        address _layerZeroEndpoint
    ) OFT("Decent Eth", "DcntEth", _layerZeroEndpoint, msg.sender) Ownable() Roles(msg.sender) {}

    /**
     * @param _router the decentEthRouter associated with this eth
     */
    function setRouter(address _router) public onlyAdmin {
        router = _router;
        emit SetRouter(_router);
    }

    function mint(address _to, uint256 _amount) public onlyRouter {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public onlyRouter {
        _burn(_from, _amount);
    }

    function mintByAdmin(address _to, uint256 _amount) public onlyAdmin {
        _mint(_to, _amount);
    }

    function burnByAdmin(address _from, uint256 _amount) public onlyAdmin {
        _burn(_from, _amount);
    }

    function owner() public view override (Ownable, AccessControlDefaultAdminRules) returns (address) {
        return Ownable.owner();
    }
}
