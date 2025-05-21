// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

interface ITakeProvider {
    function take(uint256 assets, bytes calldata data) external;
}
