// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {VerifierAware, IEventVerifier} from "../../verifier/aware/VerifierAware.sol";

import {AssetRescuer} from "../../rescue/AssetRescuer.sol";

import {Controllable} from "../../control/Controllable.sol";

import {DecimalsLib} from "../../util/libraries/DecimalsLib.sol";
import {TrackToken} from "../../util/track/TrackToken.sol";

import {ITransferTaker} from "./interfaces/ITransferTaker.sol";
import {ITransferGiver} from "./interfaces/ITransferGiver.sol";

contract TransferTaker is ITransferTaker, PoolAware, VerifierAware, AssetRescuer, Controllable, TrackToken {
    uint256 public immutable override giveChain;
    address public immutable override giveTransferGiver;
    int256 public immutable override giveDecimalsShift;

    mapping(address receiver => BitMaps.BitMap) private _takenData;

    constructor(
        IFlexPool pool_,
        IEventVerifier verifier_,
        address controller_,
        uint256 giveChain_,
        address giveTransferGiver_,
        int256 giveDecimalsShift_
    )
        PoolAware(pool_)
        VerifierAware(verifier_)
        Controllable(controller_)
    {
        giveChain = giveChain_;
        giveTransferGiver = giveTransferGiver_;
        giveDecimalsShift = giveDecimalsShift_;
    }

    function taken(address receiver_, uint256 nonce_) public view override returns (bool) {
        return BitMaps.get(_takenData[receiver_], nonce_);
    }

    function take(
        uint256 assets_,
        uint256 nonce_,
        uint256 giveAssets_,
        bytes calldata giveProof_
    ) external override trackToken(poolAsset) {
        uint256 minGiveAssets = pool.take(assets_);
        _verifyGiveAssets(minGiveAssets, giveAssets_);
        _verifyGiveEvent(giveAssets_, msg.sender, nonce_, giveProof_);
        _transitToTaken(msg.sender, nonce_);
    }

    // ---

    function _canCallRescue(address caller_) internal view override returns (bool) {
        return caller_ == controller;
    }

    function _canRescueAsset(address /* asset_ */) internal pure override returns (bool) {
        return true; // Not designed to hold asset after transaction
    }

    // ---

    function _verifyGiveAssets(uint256 minAssets_, uint256 assets_) private view {
        (uint256 commonMinAssets, uint256 commonAssets) = DecimalsLib.common(minAssets_, assets_, giveDecimalsShift);
        require(commonAssets >= commonMinAssets, InsufficientGiveAssets(commonAssets, commonMinAssets));
    }

    function _verifyGiveEvent(uint256 assets_, address receiver_, uint256 nonce_, bytes memory proof_) private {
        bytes32[] memory topics = new bytes32[](1);
        topics[0] = ITransferGiver.TransferGive.selector;
        bytes memory data = abi.encode(assets_, block.chainid, receiver_, nonce_);
        verifier.verifyEvent(giveChain, giveTransferGiver, topics, data, proof_);
    }

    function _transitToTaken(address receiver_, uint256 nonce_) private {
        require(!taken(receiver_, nonce_), AlreadyTaken(receiver_, nonce_));
        BitMaps.set(_takenData[receiver_], nonce_);
    }
}
