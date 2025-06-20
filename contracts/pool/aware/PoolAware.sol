// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IPoolAware, IFlexPool, IERC20} from "./interfaces/IPoolAware.sol";

contract PoolAware is IPoolAware {
    IFlexPool public immutable override pool;
    IERC20 public immutable override poolAsset;

    constructor(IFlexPool pool_) {
        pool = pool_;
        poolAsset = IERC20(pool_.asset());
    }
}
