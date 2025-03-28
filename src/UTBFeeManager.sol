// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IUTBFeeManager} from "./interfaces/IUTBFeeManager.sol";
import {Roles} from "./utils/Roles.sol";

contract UTBFeeManager is IUTBFeeManager, Roles {
    address public signer;
    string constant BANNER = "\x19Ethereum Signed Message:\n32";

    constructor(address _signer) Roles(msg.sender) {
        signer = _signer;
    }

    /// @inheritdoc IUTBFeeManager
    function setSigner(address _signer) public onlyAdmin {
        signer = _signer;
        emit SetSigner(_signer);
    }

    /// @inheritdoc IUTBFeeManager
    function verifySignature(
        bytes memory packedInfo,
        bytes memory signature
    ) public view {
        bytes32 constructedHash = keccak256(
            abi.encodePacked(BANNER, keccak256(packedInfo))
        );
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(signature);
        address recovered = ecrecover(constructedHash, v, r, s);
        if (recovered == address(0)) revert ZeroSig();
        if (recovered != signer) revert WrongSig();
    }

        /**
     * @dev Splits an Ethereum signature into its components (r, s, v).
     * @param signature The Ethereum signature.
     */
    function _splitSignature(
        bytes memory signature
    ) private pure returns (bytes32 r, bytes32 s, uint8 v) {
        if (signature.length != 65) revert WrongSigLength();

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
    }
}
