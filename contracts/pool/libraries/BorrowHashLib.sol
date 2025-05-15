// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

library BorrowHashLib {
    function calc(
        uint256 borrowChain_,
        uint256 borrowAssets_,
        address borrowReceiver_,
        uint256 obligateChain_,
        uint256 obligateNonce_
    ) internal pure returns (bytes32 hash) {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, borrowChain_)
            mstore(add(ptr, 0x20), borrowAssets_)
            mstore(add(ptr, 0x40), borrowReceiver_)
            mstore(add(ptr, 0x60), obligateChain_)
            mstore(add(ptr, 0x80), obligateNonce_)
            hash := keccak256(ptr, 0xa0)
        }
    }
}
