// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {LinearProtocolFossil} from "../util/protocol/LinearProtocolFossil.sol";
import {LinearRebalanceFossil} from "../util/rebalance/LinearRebalanceFossil.sol";

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {Controllable} from "../../control/Controllable.sol";

import {IElasticTuner} from "./interfaces/IElasticTuner.sol";

contract ElasticTuner is
    IElasticTuner,
    LinearProtocolFossil,
    LinearRebalanceFossil,
    PoolAware,
    Controllable,
    Multicall
{
    uint256 public transient override extraReliefAssets;
    mapping(address reliever => bool) public override relieverEnabled;

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

    modifier onlyEnabledReliever {
        require(relieverEnabled[msg.sender], CallerNotReliever(msg.sender));
        _;
    }

    function tune(uint256 assets_) public view override returns (uint256 protocolAssets, int256 rebalanceAssets) {
        return tuneRelief(assets_, extraReliefAssets);
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
                rebalanceAssets -= int256(Math.mulDiv(pool.rebalanceAssets(), relief_ * 2, relief_ + total));
            }
        }

        if (assets_ != 0) {
            rebalanceAssets += int256(_applyLinearRebalance(assets_));
        }
    }

    function setExtraReliefAssets(uint256 assets_) public override onlyEnabledReliever {
        extraReliefAssets = assets_;
    }

    function enableReliever(address reliever_) public override onlyController {
        require(!relieverEnabled[reliever_], RelieverAlreadyEnabled(reliever_));
        relieverEnabled[reliever_] = true;
        emit RelieverEnabled(reliever_);
    }

    function disableReliever(address reliever_) public override onlyController {
        require(relieverEnabled[reliever_], RelieverAlreadyDisabled(reliever_));
        relieverEnabled[reliever_] = false;
        emit RelieverDisabled(reliever_);
    }
}
