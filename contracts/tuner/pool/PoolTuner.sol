// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IPoolTuner, IFlexPool} from "./interfaces/IPoolTuner.sol";

abstract contract PoolTuner is IPoolTuner {
    IFlexPool public immutable override pool;

    constructor(IFlexPool pool_) {
        pool = pool_;
    }
}
