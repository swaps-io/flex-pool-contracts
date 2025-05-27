// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

interface IAssetRescuer {
    error RescueCallerNotAllowed(address caller);
    error RescueAssetNotAllowed(address asset);

    function rescue(address asset, uint256 amount, address to) external;
}
