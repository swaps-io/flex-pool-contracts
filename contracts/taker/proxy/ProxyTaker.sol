// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {AssetRescuer} from "../../rescue/AssetRescuer.sol";

import {Controllable} from "../../control/Controllable.sol";

import {IProxyTaker} from "./interfaces/IProxyTaker.sol";

contract ProxyTaker is IProxyTaker, PoolAware, AssetRescuer, Controllable {
    mapping(address proxy => mapping(address implementation => bool)) public override implementationEnabled;

    constructor(IFlexPool pool_, address controller_)
        PoolAware(pool_)
        Controllable(controller_)
    {}

    modifier onlyProxy {
        address implementation = IBeacon(msg.sender).implementation();
        require(implementationEnabled[msg.sender][implementation], ImplementationDisabled(msg.sender, implementation));
        _;
    }

    // ---

    function enableImplementation(address proxy_, address implementation_) public override onlyController {
        require(!implementationEnabled[proxy_][implementation_], ImplementationAlreadyEnabled(proxy_, implementation_));
        implementationEnabled[proxy_][implementation_] = true;
        emit ImplementationEnable(proxy_, implementation_);
    }

    function disableImplementation(address proxy_, address implementation_) public override onlyController {
        require(implementationEnabled[proxy_][implementation_], ImplementationAlreadyDisabled(proxy_, implementation_));
        implementationEnabled[proxy_][implementation_] = false;
        emit ImplementationDisable(proxy_, implementation_);
    }

    function take(uint256 assets_) public override onlyProxy returns (uint256 takeAssets, uint256 minGiveAssets) {
        (takeAssets, minGiveAssets) = pool.take(assets_);
        SafeERC20.safeTransfer(poolAsset, msg.sender, takeAssets);
    }

    // ---

    function _canCallRescue(address caller_) internal view override returns (bool) {
        return caller_ == controller;
    }

    function _canRescueAsset(address /* asset_ */) internal pure override returns (bool) {
        return true; // Not designed to hold asset after transaction
    }
}
