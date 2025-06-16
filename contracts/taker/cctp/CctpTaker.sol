// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {AssetRescuer} from "../../rescue/AssetRescuer.sol";

import {Controllable} from "../../control/Controllable.sol";

import {TrackToken} from "../../util/track/TrackToken.sol";

import {ICctpTaker, ITokenMessengerV2} from "./interfaces/ICctpTaker.sol";

contract CctpTaker is ICctpTaker, PoolAware, AssetRescuer, Controllable, TrackToken {
    ITokenMessengerV2 public immutable override tokenMessenger;
    uint32 public immutable override giveDomain;
    address public immutable override givePool;

    constructor(
        IFlexPool pool_,
        address controller_,
        ITokenMessengerV2 tokenMessenger_,
        uint32 giveDomain_,
        address givePool_
    )
        PoolAware(pool_)
        Controllable(controller_)
    {
        tokenMessenger = tokenMessenger_;
        giveDomain = giveDomain_;
        givePool = givePool_;

        // Provide infinite allowance to the token messenger. Any `msg.sender` interactions are limited by the take
        // logic below. The logic ensures only taken asset can be spent, and none of this asset is left in this
        // contract after. Also no contract signature verification allowed for potential permit interactions.
        poolAsset.approve(address(tokenMessenger_), type(uint256).max);
    }

    function takeToBurn(uint256 assets_, uint256 cctpAmount_, uint256 cctpMaxFee_) public override {
        _verifyCctpFee(cctpAmount_, cctpMaxFee_);

        uint256 baseAssets = _trackTokenBefore(poolAsset);
        uint256 minGiveAssets = pool.take(assets_);
        uint256 takeAssets = _trackTokenBefore(poolAsset) - baseAssets;
        _verifyTakeAssets(takeAssets, cctpAmount_);
        _verifyGiveAssets(cctpAmount_ - cctpMaxFee_, minGiveAssets);

        _burn(cctpAmount_, cctpMaxFee_);
        _trackTokenAfter(poolAsset, baseAssets);
    }

    // ---

    function _canCallRescue(address caller_) internal view override returns (bool) {
        return caller_ == controller;
    }

    function _canRescueAsset(address /* asset_ */) internal pure override returns (bool) {
        return true; // Not designed to hold asset after transaction
    }

    // ---

    function _verifyCctpFee(uint256 amount_, uint256 maxFee_) private pure {
        require(amount_ >= maxFee_, ExcessiveCctpFee(maxFee_, amount_));
    }

    function _verifyTakeAssets(uint256 assets_, uint256 minAssets_) private pure {
        require(assets_ >= minAssets_, InsufficientTakeAssets(assets_, minAssets_));
    }

    function _verifyGiveAssets(uint256 assets_, uint256 minAssets_) private pure {
        require(assets_ >= minAssets_, InsufficientGiveAssets(assets_, minAssets_));
    }

    function _address32(address value_) private pure returns (bytes32) {
        return bytes32(uint256(uint160(value_)));
    }

    function _burn(uint256 amount_, uint256 maxFee_) private {
        // Destination pool will receive at least `amount` - `maxFee`.
        tokenMessenger.depositForBurn(
            amount_,              // uint256 amount
            giveDomain,           // uint32  destinationDomain
            _address32(givePool), // bytes32 mintRecipient
            address(poolAsset),   // address burnToken
            0,                    // bytes32 destinationCaller
            maxFee_,              // uint256 maxFee
            0                     // uint32  minFinalityThreshold
        );
    }
}
