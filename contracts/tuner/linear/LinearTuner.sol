// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {PercentLib, Math} from "../../util/libraries/PercentLib.sol";

import {ILinearTuner} from "./interfaces/ILinearTuner.sol";

contract LinearTuner is ILinearTuner, PoolAware {
    uint256 public immutable override protocolFixed;
    uint256 public immutable override protocolPercent;
    uint256 public immutable override rebalanceFixed;
    uint256 public immutable override rebalancePercent;

    constructor(
        IFlexPool pool_,
        uint256 protocolFixed_,
        uint256 protocolPercent_,
        uint256 rebalanceFixed_,
        uint256 rebalancePercent_
    )
        PoolAware(pool_)
    {
        protocolFixed = protocolFixed_;
        protocolPercent = protocolPercent_;
        rebalanceFixed = rebalanceFixed_;
        rebalancePercent = rebalancePercent_;
    }

    function tune(uint256 assets_) public view override returns (uint256 protocolAssets, int256 rebalanceAssets) {
        protocolAssets = protocolFixed + PercentLib.applyPercent(assets_, protocolPercent);

        int256 equilibrium = pool.equilibriumAssets();
        if (equilibrium > 0) {
            uint256 relieve = Math.min(uint256(equilibrium), assets_);
            rebalanceAssets -= int256(Math.mulDiv(pool.rebalanceAssets(), relieve, uint256(equilibrium)));
            assets_ -= relieve;
        }
        if (assets_ != 0) {
            rebalanceAssets += int256(rebalanceFixed + PercentLib.applyPercent(assets_, rebalancePercent));
        }
    }
}
