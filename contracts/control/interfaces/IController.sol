// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

// Inherits OpenZeppelin's `Ownable2Step` interface.

interface IController {
    function execute(address target, bytes calldata data, uint256 value) external payable; // Only owner
}
