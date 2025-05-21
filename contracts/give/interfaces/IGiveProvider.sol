// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

interface IGiveProvider {
    function give(uint256 assets, bytes calldata data) external;
}
