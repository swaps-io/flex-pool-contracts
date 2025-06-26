// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ITransferShiftGiver, IEquilibriumShift} from "./interfaces/ITransferShiftGiver.sol";

import {TransferGiver, ITransferGiver, IFlexPool, SafeERC20} from "./TransferGiver.sol";

contract TransferShiftGiver is ITransferShiftGiver, TransferGiver {
    IEquilibriumShift public immutable override tuner;

    constructor(
        IFlexPool pool_,
        address controller_,
        IEquilibriumShift tuner_
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
        _takeSurplus(assets_);
    }

    function giveHold(
        uint256 assets_,
        uint256 takeChain_,
        address takeReceiver_,
        uint256 takeNonce_
    ) public override(ITransferGiver, TransferGiver) {
        super.give(assets_, takeChain_, takeReceiver_, takeNonce_);
        _takeSurplus(assets_);
    }

    // ---

    function _takeSurplus(uint256 assets_) private {
        tuner.setEquilibriumShift(int256(assets_));
        (uint256 takeAssets, uint256 minGiveAssets) = pool.take(0);
        tuner.setEquilibriumShift(0);

        require(takeAssets >= minGiveAssets, InsufficientTakeSurplus(takeAssets, minGiveAssets));
        if (minGiveAssets != 0) {
            SafeERC20.safeTransfer(poolAsset, address(pool), minGiveAssets);
        }
        if (takeAssets > minGiveAssets) {
            SafeERC20.safeTransfer(poolAsset, msg.sender, takeAssets - minGiveAssets);
        }
    }
}
