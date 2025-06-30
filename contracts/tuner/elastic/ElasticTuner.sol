// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {LinearProtocolFossil} from "../util/protocol/LinearProtocolFossil.sol";
import {LinearRebalanceFossil} from "../util/rebalance/LinearRebalanceFossil.sol";

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {IElasticTuner} from "./interfaces/IElasticTuner.sol";

contract ElasticTuner is IElasticTuner, LinearProtocolFossil, LinearRebalanceFossil, PoolAware {
    uint256 public transient override extraReliefAssets;
    address public transient override extraReliefSetter;

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
        uint256 relief = extraReliefAssets;
        if (relief != 0) {
            address tuner = pool.tuner(extraReliefSetter);
            require(tuner == address(this), InvalidExtraReliefSetter(extraReliefSetter, tuner));
        }

        return tuneRelief(assets_, relief);
    }

    function tuneRelief(
        uint256 assets_,
        uint256 relief_
    ) public view override returns (
        uint256 protocolAssets,
        int256 rebalanceAssets
    ) {
        protocolAssets = _applyLinearProtocol(assets_);

        int256 equilibrium = pool.equilibriumAssets();
        if (equilibrium > 0) {
            uint256 equilibriumRelief = Math.min(uint256(equilibrium), assets_);
            relief_ += equilibriumRelief;
            assets_ -= equilibriumRelief;
        }

        if (relief_ != 0) {
            uint256 total = pool.totalAssets();
            if (total != 0) {
                relief_ = Math.min(relief_, total);
                rebalanceAssets -= int256(Math.mulDiv(pool.rebalanceAssets(), relief_, total));
            }
        }

        if (assets_ != 0) {
            rebalanceAssets += int256(_applyLinearRebalance(assets_));
        }
    }

    function setExtraReliefAssets(uint256 assets_) public override {
        extraReliefAssets = assets_;
        if (assets_ != 0) {
            extraReliefSetter = msg.sender;
        }
    }
}
