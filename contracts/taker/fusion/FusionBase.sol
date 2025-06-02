// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {AssetRescuer} from "../../rescue/AssetRescuer.sol";

import {Controllable} from "../../control/Controllable.sol";

import {TrackAsset} from "../../util/track/TrackAsset.sol";

import {IFusionBase, IBaseEscrow} from "./interfaces/IFusionBase.sol";

abstract contract FusionBase is IFusionBase, PoolAware, AssetRescuer, Controllable, TrackAsset {
    address public immutable override escrowFactory;

    mapping(address escrow => address) public override originalTaker;

    constructor(
        IFlexPool pool_,
        address controller_,
        address escrowFactory_
    )
        PoolAware(pool_)
        Controllable(controller_)
    {
        escrowFactory = escrowFactory_;
    }

    modifier returnPoolAsset {
        _;
        _trackTokenAfter(poolAsset, 0, address(pool));
    }

    modifier onlyOriginalTaker(address escrow_) {
        address taker = originalTaker[escrow_];
        require(msg.sender == taker, CallerNotOriginalTaker(msg.sender, escrow_, taker));
        _;
    }

    // ---

    function predictEscrow(IBaseEscrow.Immutables calldata immutables_) public view returns (address) {
        return _predictEscrow(immutables_);
    }

    function transferAssetToPool() public override returnPoolAsset {}

    // `IBaseEscrow` compatibility

    function rescueFunds(address token_, uint256 amount_, IBaseEscrow.Immutables calldata immutables_) public override {
        rescueFundsEscrow(_predictEscrow(immutables_), token_, amount_, immutables_);
    }

    // `IBaseEscrow` using pre-calculated address

    function rescueFundsEscrow(
        address escrow_,
        address token_,
        uint256 amount_,
        IBaseEscrow.Immutables calldata immutables_
    ) public override
        onlyOriginalTaker(escrow_)
        trackAsset(token_)
    {
        IBaseEscrow(escrow_).rescueFunds(token_, amount_, immutables_);
    }

    // ---

    function _saveOriginalTaker(IBaseEscrow.Immutables memory immutables_, address originalTaker_) internal {
        originalTaker[_predictEscrow(immutables_)] = originalTaker_;
    }

    function _predictEscrow(IBaseEscrow.Immutables memory immutables) internal view virtual returns (address);

    // ---

    function _canCallRescue(address caller_) internal view override returns (bool) {
        return caller_ == controller;
    }

    function _canRescueAsset(address asset_) internal view override returns (bool) {
        return asset_ != address(poolAsset);
    }
}
