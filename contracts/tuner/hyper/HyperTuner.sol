// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {Controllable} from "../../control/Controllable.sol";

import {PercentLib, Math} from "../../util/libraries/PercentLib.sol";

import {IHyperTuner} from "./interfaces/IHyperTuner.sol";

contract HyperTuner is IHyperTuner, PoolAware, Controllable {
    uint256 public immutable override protocolFixed;
    uint256 public immutable override protocolPercent;
    uint256 public immutable override rebalanceFixed;
    uint256 public immutable override rebalancePercent;

    int256 public transient override equilibriumShift;
    mapping(address shifter => bool) public override equilibriumShifter;

    constructor(
        IFlexPool pool_,
        address controller_,
        uint256 protocolFixed_,
        uint256 protocolPercent_,
        uint256 rebalanceFixed_,
        uint256 rebalancePercent_
    )
        PoolAware(pool_)
        Controllable(controller_)
    {
        protocolFixed = protocolFixed_;
        protocolPercent = protocolPercent_;
        rebalanceFixed = rebalanceFixed_;
        rebalancePercent = rebalancePercent_;
    }

    modifier onlyEquilibriumShifter {
        require(equilibriumShifter[msg.sender], CallerNotEquilibriumShifter(msg.sender));
        _;
    }

    function tune(uint256 assets_) public view override returns (uint256 protocolAssets, int256 rebalanceAssets) {
        protocolAssets = protocolFixed + PercentLib.applyPercent(assets_, protocolPercent);

        int256 equilibrium = pool.equilibriumAssets() + equilibriumShift;
        if (equilibrium > 0) {
            uint256 relief = Math.min(uint256(equilibrium), assets_);
            assets_ -= relief;

            uint256 total = pool.totalAssets();
            if (total != 0) {
                relief = Math.min(relief, total);
                rebalanceAssets -= int256(Math.mulDiv(pool.rebalanceAssets(), relief * 2, relief + total));
            }
        }

        if (assets_ != 0) {
            rebalanceAssets += int256(rebalanceFixed + PercentLib.applyPercent(assets_, rebalancePercent));
        }
    }

    function setEquilibriumShift(int256 assets_) public override onlyEquilibriumShifter {
        equilibriumShift = assets_;
    }

    function enableEquilibriumShifter(address shifter_) public override onlyController {
        require(!equilibriumShifter[shifter_], EquilibriumShifterAlreadyEnabled(shifter_));
        equilibriumShifter[shifter_] = true;
        emit EquilibriumShifterEnabled(shifter_);
    }

    function disableEquilibriumShifter(address shifter_) public override onlyController {
        require(equilibriumShifter[shifter_], EquilibriumShifterAlreadyDisabled(shifter_));
        equilibriumShifter[shifter_] = false;
        emit EquilibriumShifterDisabled(shifter_);
    }
}
