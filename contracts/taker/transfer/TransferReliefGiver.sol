// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ITransferReliefGiver, ITransferReliefTuner} from "./interfaces/ITransferReliefGiver.sol";

import {TransferGiver, ITransferGiver, IFlexPool, SafeERC20} from "./TransferGiver.sol";

contract TransferReliefGiver is ITransferReliefGiver, TransferGiver {
    ITransferReliefTuner public immutable override tuner;

    constructor(
        IFlexPool pool_,
        address controller_,
        ITransferReliefTuner tuner_
    )
        TransferGiver(pool_, controller_)
    {
        tuner = tuner_;
    }

    function give(
        uint256 assets_,
        uint256 takeChain_,
        address takeReceiver_,
        uint256 takeNonce_
    ) public override(ITransferGiver, TransferGiver) {
        super.give(assets_, takeChain_, takeReceiver_, takeNonce_);
        _takeReliefSurplus(assets_);
    }

    function giveHold(
        uint256 assets_,
        uint256 takeChain_,
        address takeReceiver_,
        uint256 takeNonce_
    ) public override(ITransferGiver, TransferGiver) {
        super.giveHold(assets_, takeChain_, takeReceiver_, takeNonce_);
        _takeReliefSurplus(assets_);
    }

    // ---

    function _takeReliefSurplus(uint256 assets_) private {
        int256 equilibrium = pool.equilibriumAssets();
        if (equilibrium > 0) {
            assets_ -= Math.min(assets_, uint256(equilibrium));
        }
        if (assets_ == 0) {
            return;
        }

        tuner.setExtraReliefAssets(assets_);
        (uint256 protocolAssets, int256 rebalanceAssets) = tuner.tune(0);
        if (int256(protocolAssets) >= -rebalanceAssets) {
            tuner.setExtraReliefAssets(0);
            return;
        }

        (uint256 takeAssets, uint256 minGiveAssets) = pool.take(0);
        tuner.setExtraReliefAssets(0);

        SafeERC20.safeTransfer(poolAsset, address(pool), minGiveAssets);
        SafeERC20.safeTransfer(poolAsset, msg.sender, takeAssets - minGiveAssets);
    }
}
