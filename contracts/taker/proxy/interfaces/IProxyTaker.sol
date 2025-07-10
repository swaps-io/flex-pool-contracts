// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IPoolAware} from "../../../pool/aware/interfaces/IPoolAware.sol";

import {IAssetRescuer} from "../../../rescue/interfaces/IAssetRescuer.sol";

import {IControllable} from "../../../control/interfaces/IControllable.sol";

interface IProxyTaker is IPoolAware, IAssetRescuer, IControllable {
    event ImplementationEnable(address indexed proxy, address indexed implementation);
    event ImplementationDisable(address indexed proxy, address indexed implementation);

    error ImplementationDisabled(address proxy, address implementation);
    error ImplementationAlreadyEnabled(address proxy, address implementation);
    error ImplementationAlreadyDisabled(address proxy, address implementation);

    function implementationEnabled(address proxy, address implementation) external view returns (bool);

    function enableImplementation(address proxy, address implementation) external; // Only controller

    function disableImplementation(address proxy, address implementation) external; // Only controller

    function take(uint256 assets) external returns (uint256 takeAssets, uint256 minGiveAssets); // Only proxy w/ impl
}
