// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {PoolAware, IFlexPool} from "../../aware/PoolAware.sol";

import {TakeDeadlineLib} from "../../pool/libraries/TakeDeadlineLib.sol";
import {DeadlineLib} from "../../pool/libraries/DeadlineLib.sol";

import {TuneProviderParams} from "../structs/TuneProviderParams.sol";
import {TuneProviderResult} from "../structs/TuneProviderResult.sol";

import {PercentLib, Math} from "../libraries/PercentLib.sol";

import {ILinearTuneProvider} from "./interfaces/ILinearTuneProvider.sol";

import {LinearTuneProviderParams} from "./structs/LinearTuneProviderParams.sol";

contract LinearTuneProvider is ILinearTuneProvider, PoolAware {
    uint256 public immutable override maxTakeDeadlineTime;
    uint256 public immutable override maxTakeDeadlineTimePercent;
    uint256 public immutable override maxExclusiveCancelTime;
    uint256 public immutable override maxExclusiveCancelTimePercent;
    uint256 public immutable override escrowValueConstant;
    uint256 public immutable override escrowValuePercent;
    uint256 public immutable override escrowAssetsConvertPercent;
    uint256 public immutable override protocolAssetsConstant;
    uint256 public immutable override protocolAssetsPercent;
    uint256 public immutable override rebalanceAssetsConstant;
    uint256 public immutable override rebalanceAssetsPercent;

    constructor(LinearTuneProviderParams memory params_)
        PoolAware(IFlexPool(params_.pool))
    {
        maxTakeDeadlineTime = params_.maxTakeDeadlineTime;
        maxTakeDeadlineTimePercent = params_.maxTakeDeadlineTimePercent;
        maxExclusiveCancelTime = params_.maxExclusiveCancelTime;
        maxExclusiveCancelTimePercent = params_.maxExclusiveCancelTimePercent;
        escrowValueConstant = params_.escrowValueConstant;
        escrowValuePercent = params_.escrowValuePercent;
        escrowAssetsConvertPercent = params_.escrowAssetsConvertPercent;
        protocolAssetsConstant = params_.protocolAssetsConstant;
        protocolAssetsPercent = params_.protocolAssetsPercent;
        rebalanceAssetsConstant = params_.rebalanceAssetsConstant;
        rebalanceAssetsPercent = params_.rebalanceAssetsPercent;
    }

    function tune(
        TuneProviderParams calldata params_
    ) external view override returns (
        TuneProviderResult memory result
    ) {
        uint256 timeAssets = _tuneTimeAssets(params_.takeAssets, params_.takeDeadline);
        result.escrowValue = _tuneEscrowValue(timeAssets);
        result.protocolAssets = _tuneProtocolAssets(timeAssets);
        result.rebalanceAssets = _tuneRebalanceAssets(params_.takeAssets);
    }

    function _tuneTimeAssets(uint256 takeAssets_, uint256 takeDeadline_) private view returns (uint256 timeAssets) {
        timeAssets = takeAssets_;

        if (maxTakeDeadlineTimePercent > 0) {
            uint256 takeDeadline = TakeDeadlineLib.readTakeDeadline(takeDeadline_);
            require(DeadlineLib.active(takeDeadline), TakeDeadlineInactive(DeadlineLib.time(), takeDeadline));

            uint256 takeDeadlineTime = DeadlineLib.remain(takeDeadline);
            require(
                takeDeadlineTime <= maxTakeDeadlineTime,
                MaxTakeDeadlineTimeExceeded(takeDeadlineTime, maxTakeDeadlineTime)
            );

            timeAssets += PercentLib.calcPercent(maxTakeDeadlineTime - takeDeadlineTime, maxTakeDeadlineTimePercent);
        }

        if (maxExclusiveCancelTimePercent > 0) {
            uint256 exclusiveCancelTime = TakeDeadlineLib.readExclusiveCancelTime(takeDeadline_);
            require(
                exclusiveCancelTime <= maxExclusiveCancelTime,
                MaxExclusiveCancelTimeExceeded(exclusiveCancelTime, maxExclusiveCancelTime)
            );

            timeAssets += PercentLib.calcPercent(maxExclusiveCancelTime - exclusiveCancelTime, maxExclusiveCancelTimePercent);
        }
    }

    function _tuneEscrowValue(uint256 timeAssets_) private view returns (uint256 escrowValue) {
        return escrowValueConstant + PercentLib.calcPercent(
            PercentLib.calcPercent(timeAssets_, escrowAssetsConvertPercent),
            escrowValuePercent
        );
    }

    function _tuneProtocolAssets(uint256 timeAssets_) private view returns (uint256 protocolAssets) {
        return protocolAssetsConstant + PercentLib.calcPercent(timeAssets_, protocolAssetsPercent);
    }

    function _tuneRebalanceAssets(uint256 takeAssets_) private view returns (uint256 rebalanceAssets) {
        rebalanceAssets = rebalanceAssetsConstant;
        if (rebalanceAssetsPercent > 0) {
            int256 affectedEquilibrium = pool.equilibriumAssets() + int256(takeAssets_);
            if (affectedEquilibrium > 0) {
                uint256 equilibriumRebalance = Math.min(uint256(affectedEquilibrium), takeAssets_);
                rebalanceAssets += PercentLib.calcPercent(equilibriumRebalance, rebalanceAssetsPercent);
            }
        }
    }
}
