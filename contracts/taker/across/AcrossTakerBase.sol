// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {AssetRescuer} from "../../rescue/AssetRescuer.sol";

import {Controllable} from "../../control/Controllable.sol";

import {TrackToken} from "../../util/track/TrackToken.sol";
import {DecimalsLib} from "../../util/libraries/DecimalsLib.sol";

import {IAcrossTakerBase, V3SpokePoolInterface} from "./interfaces/IAcrossTakerBase.sol";

abstract contract AcrossTakerBase is IAcrossTakerBase, PoolAware, AssetRescuer, Controllable, TrackToken {
    V3SpokePoolInterface public immutable spokePool;
    uint256 public immutable override giveChain;
    address public immutable override givePool;
    address public immutable override givePoolAsset;
    int256 public immutable override giveDecimalsShift;

    constructor(
        IFlexPool pool_,
        address controller_,
        V3SpokePoolInterface spokePool_,
        uint256 giveChain_,
        address givePool_,
        address givePoolAsset_,
        int256 giveDecimalsShift_
    )
        PoolAware(pool_)
        Controllable(controller_)
    {
        spokePool = spokePool_;
        giveChain = giveChain_;
        givePool = givePool_;
        givePoolAsset = givePoolAsset_;
        giveDecimalsShift = giveDecimalsShift_;

        // Provide infinite allowance to the spoke pool. Any `msg.sender` interactions are limited by the take logic.
        // The logic ensures only taken asset can be spent, and none of this asset is left in this contract after.
        // Also no contract signature verification allowed for potential permit interactions.
        poolAsset.approve(address(spokePool_), type(uint256).max);
    }

    // ---

    function _canCallRescue(address caller_) internal view override returns (bool) {
        return caller_ == controller;
    }

    function _canRescueAsset(address /* asset_ */) internal pure override returns (bool) {
        return true; // Not designed to hold asset after transaction
    }

    // ---

    function _address32(address value_) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(value_)));
    }

    function _verifyTakeAssets(uint256 assets_, uint256 minAssets_) internal pure {
        require(assets_ >= minAssets_, InsufficientTakeAssets(assets_, minAssets_));
    }

    function _verifyGiveAssets(uint256 assets_, uint256 minAssets_) internal view {
        (uint256 commonMinAssets, uint256 commonAssets) = DecimalsLib.common(minAssets_, assets_, giveDecimalsShift);
        require(commonAssets >= commonMinAssets, InsufficientGiveAssets(commonAssets, commonMinAssets));
    }
}
