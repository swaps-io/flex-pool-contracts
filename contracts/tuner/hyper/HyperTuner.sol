// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {LinearProtocolFossil} from "../util/protocol/LinearProtocolFossil.sol";
import {LinearRebalanceFossil} from "../util/rebalance/LinearRebalanceFossil.sol";

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {Controllable} from "../../control/Controllable.sol";

import {IHyperTuner} from "./interfaces/IHyperTuner.sol";

contract HyperTuner is IHyperTuner, LinearProtocolFossil, LinearRebalanceFossil, PoolAware, Controllable {
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
        LinearProtocolFossil(protocolFixed_, protocolPercent_)
        LinearRebalanceFossil(rebalanceFixed_, rebalancePercent_)
        PoolAware(pool_)
        Controllable(controller_)
    {}

    modifier onlyEquilibriumShifter {
        require(equilibriumShifter[msg.sender], CallerNotEquilibriumShifter(msg.sender));
        _;
    }

    function tune(uint256 assets_) public view override returns (uint256 protocolAssets, int256 rebalanceAssets) {
        protocolAssets = _applyLinearProtocol(assets_);

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
            rebalanceAssets += int256(_applyLinearRebalance(assets_));
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
