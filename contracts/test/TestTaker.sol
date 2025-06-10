// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {PoolAware, IFlexPool} from "../pool/aware/PoolAware.sol";

contract TestTaker is PoolAware {
    error InvalidMinGiveAssets(uint256 assets, uint256 expectedAssets);

    constructor(IFlexPool pool_)
        PoolAware(pool_)
    {}

    function take(uint256 assets_, uint256 expectedMinGiveAssets_) public {
        uint256 minGiveAssets = pool.take(assets_);
        require(minGiveAssets == expectedMinGiveAssets_, InvalidMinGiveAssets(minGiveAssets, expectedMinGiveAssets_));
    }
}
