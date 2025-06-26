// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {LinearProtocolFossil} from "../util/protocol/LinearProtocolFossil.sol";
import {LinearRebalanceFossil} from "../util/rebalance/LinearRebalanceFossil.sol";

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {ILinearTuner} from "./interfaces/ILinearTuner.sol";

contract LinearTuner is ILinearTuner, LinearProtocolFossil, LinearRebalanceFossil, PoolAware {
    constructor(
        IFlexPool pool_,
        uint256 protocolFixed_,
        uint256 protocolPercent_,
        uint256 rebalanceFixed_,
        uint256 rebalancePercent_
    )
        LinearProtocolFossil(protocolFixed_, protocolPercent_)
        LinearRebalanceFossil(rebalanceFixed_, rebalancePercent_)
        PoolAware(pool_)
    {}

    function tune(uint256 assets_) public view override returns (uint256 protocolAssets, int256 rebalanceAssets) {
        protocolAssets = _applyLinearProtocol(assets_);

        int256 equilibrium = pool.equilibriumAssets();
        if (equilibrium > 0) {
            uint256 relief = Math.min(uint256(equilibrium), assets_);
            rebalanceAssets -= int256(Math.mulDiv(pool.rebalanceAssets(), relief, uint256(equilibrium)));
            assets_ -= relief;
        }
        if (assets_ != 0) {
            rebalanceAssets += int256(_applyLinearRebalance(assets_));
        }
    }
}
