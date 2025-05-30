// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

// Essentials of `@1inch/cross-chain-swap/contracts/interfaces/IMerkleStorageInvalidator.sol` with relaxed pragma

interface IMerkleStorageInvalidator {
    function lastValidated(bytes32 key) external view returns (uint256 index, bytes32 leaf);
}
