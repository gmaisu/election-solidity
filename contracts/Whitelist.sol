// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract WhitelistStorage is AccessControlEnumerable {

    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    mapping(address => bool) public whitelisted;

    event Whitelist(address account);

    function whitelist(address account, uint16 networkId, bytes memory signature) external {
        require(!whitelisted[account], "Account already whitelisted");

        bytes32 hashWithoutPrefix = keccak256(abi.encodePacked(toUint(account), networkId)); // TODO account or msg.sender ???
        verifySigner(hashWithoutPrefix, signature);

        whitelisted[account] = true;

        emit Whitelist(account);
    }

    function verifySigner(bytes32 hashWithoutPrefix, bytes memory signature) internal view {
        // This recreates the message hash that was signed on the client.
        bytes32 hash = prefixed(hashWithoutPrefix);
        // Verify that the message's signer is the owner
        address recoveredSigner = recoverSigner(hash, signature);

        require(hasRole(SIGNER_ROLE, recoveredSigner), "Signer doesn't have SIGNER role");
    }

    function recoverSigner(bytes32 message, bytes memory sig) internal pure returns (address) {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    function splitSignature(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        require(sig.length == 65);

        assembly {
        // first 32 bytes, after the length prefix.
            r := mload(add(sig, 32))
        // second 32 bytes.
            s := mload(add(sig, 64))
        // final byte (first byte of the next 32 bytes).
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    function toUint(address _address) internal pure virtual returns (uint256) {
        return uint256(uint160(_address));
    }

}
