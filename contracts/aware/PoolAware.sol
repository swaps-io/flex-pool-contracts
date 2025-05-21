// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IPoolAware, IFlexPool, IERC20} from "./interfaces/IPoolAware.sol";

abstract contract PoolAware is IPoolAware {
    IFlexPool public immutable override pool;
    IERC20 public immutable override poolAsset;

    modifier onlyPool {
        require(msg.sender == address(pool), CallerNotPool(msg.sender, address(pool)));
        _;
    }

    constructor(IFlexPool pool_) {
        pool = pool_;
        poolAsset = IERC20(pool_.asset());
    }
}
