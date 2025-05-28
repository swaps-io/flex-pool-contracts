// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {PercentLib, Math} from "../../util/libraries/PercentLib.sol";

import {ILinearTuner, IFlexPool} from "./interfaces/ILinearTuner.sol";

contract LinearTuner is ILinearTuner {
    IFlexPool public immutable override pool;
    uint256 public immutable override protocolPercent;
    uint256 public immutable override rebalancePercent;

    constructor(
        IFlexPool pool_,
        uint256 protocolPercent_,
        uint256 rebalancePercent_
    ) {
        pool = pool_;
        protocolPercent = protocolPercent_;
        rebalancePercent = rebalancePercent_;
    }

    function tune(
        uint256 assets_,
        bytes calldata /* data_ */
    ) public view override returns (
        uint256 protocolAssets,
        int256 rebalanceAssets
    ) {
        protocolAssets = PercentLib.applyPercent(assets_, protocolPercent);

        int256 equilibrium = pool.equilibriumAssets();
        if (equilibrium > 0) {
            uint256 relieve = Math.min(uint256(equilibrium), assets_);
            rebalanceAssets -= int256(Math.mulDiv(pool.rebalanceAssets(), relieve, uint256(equilibrium)));
            assets_ -= relieve;
        }
        rebalanceAssets += int256(PercentLib.applyPercent(assets_, rebalancePercent));
    }
}
