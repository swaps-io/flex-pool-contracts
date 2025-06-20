// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {PoolAware, IFlexPool} from "../pool/aware/PoolAware.sol";

contract TestTaker is PoolAware {
    error AlreadyTaken(bytes32 id);
    error InvalidTakeAssets(uint256 assets, uint256 expectedAssets);
    error InvalidMinGiveAssets(uint256 assets, uint256 expectedAssets);

    mapping(bytes32 id => bool) public taken;

    constructor(IFlexPool pool_)
        PoolAware(pool_)
    {}

    function take(bytes32 id_, uint256 assets_, uint256 expectedTakeAssets_, uint256 expectedMinGiveAssets_) public {
        require(!taken[id_], AlreadyTaken(id_));
        taken[id_] = true;

        (uint256 takeAssets, uint256 minGiveAssets) = pool.take(assets_);
        require(takeAssets == expectedTakeAssets_, InvalidTakeAssets(takeAssets, expectedTakeAssets_));
        require(minGiveAssets == expectedMinGiveAssets_, InvalidMinGiveAssets(minGiveAssets, expectedMinGiveAssets_));
    }
}
