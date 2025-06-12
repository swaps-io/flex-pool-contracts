// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {VerifierAware, IEventVerifier} from "../../verifier/aware/VerifierAware.sol";

import {AssetRescuer} from "../../rescue/AssetRescuer.sol";

import {Controllable} from "../../control/Controllable.sol";

import {DecimalsLib} from "../../util/libraries/DecimalsLib.sol";
import {TrackToken} from "../../util/track/TrackToken.sol";

import {IAcrossTaker, V3SpokePoolInterface} from "./interfaces/IAcrossTaker.sol";

contract AcrossTaker is IAcrossTaker, PoolAware, VerifierAware, AssetRescuer, Controllable, TrackToken {
    V3SpokePoolInterface public immutable spokePool;
    uint256 public immutable override giveChain;
    address public immutable override givePool;
    address public immutable override givePoolAsset;
    address public immutable override giveSpokePool;
    int256 public immutable override giveDecimalsShift;

    constructor(
        IFlexPool pool_,
        IEventVerifier verifier_,
        address controller_,
        V3SpokePoolInterface spokePool_,
        uint256 giveChain_,
        address givePool_,
        address givePoolAsset_,
        address giveSpokePool_,
        int256 giveDecimalsShift_
    )
        PoolAware(pool_)
        VerifierAware(verifier_)
        Controllable(controller_)
    {
        spokePool = spokePool_;
        giveChain = giveChain_;
        givePool = givePool_;
        givePoolAsset = givePoolAsset_;
        giveSpokePool = giveSpokePool_;
        giveDecimalsShift = giveDecimalsShift_;

        // Provide infinite allowance to the spoke pool. Any `msg.sender` interactions are limited by logic below.
        // The logic ensures only taken asset can be spent, and none of this asset is left in this contract after.
        // Also no contract signature verification allowed for potential permit interactions.
        poolAsset.approve(address(spokePool_), type(uint256).max);
    }

    function takeToFillRelay(
        uint256 assets_,
        uint256 inputAmount_,
        uint256 outputAmount_,
        uint256 depositId_,
        uint32 quoteTimestamp_,
        uint32 fillDeadline_,
        uint32 exclusivityDeadline_,
        bytes32 depositor_,
        bytes32 recipient_,
        bytes32 exclusiveRelayer_,
        bytes calldata message_,
        bytes calldata depositProof_
    ) public override {
        uint256 baseAssets = _trackTokenBefore(poolAsset);
        uint256 minGiveAssets = pool.take(assets_);
        uint256 takeAssets = _trackTokenBefore(poolAsset) - baseAssets;
        _verifyTakeAssets(takeAssets, outputAmount_);

        _verifyGiveAssets(inputAmount_, minGiveAssets);
        _verifyGiveEvent(
            inputAmount_,
            outputAmount_,
            depositId_,
            quoteTimestamp_,
            fillDeadline_,
            exclusivityDeadline_,
            depositor_,
            recipient_,
            exclusiveRelayer_,
            message_,
            depositProof_
        );

        _fillRelay(
            inputAmount_,
            outputAmount_,
            depositId_,
            fillDeadline_,
            exclusivityDeadline_,
            depositor_,
            recipient_,
            exclusiveRelayer_,
            message_
        );
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

    function _verifyTakeAssets(uint256 assets_, uint256 minAssets_) private pure {
        require(assets_ >= minAssets_, InsufficientTakeAssets(assets_, minAssets_));
    }

    function _verifyGiveAssets(uint256 assets_, uint256 minAssets_) private view {
        (uint256 commonMinAssets, uint256 commonAssets) = DecimalsLib.common(minAssets_, assets_, giveDecimalsShift);
        require(commonAssets >= commonMinAssets, InsufficientGiveAssets(commonAssets, commonMinAssets));
    }

    function _verifyGiveEvent(
        uint256 inputAmount_,
        uint256 outputAmount_,
        uint256 depositId_,
        uint32 quoteTimestamp_,
        uint32 fillDeadline_,
        uint32 exclusivityDeadline_,
        bytes32 depositor_,
        bytes32 recipient_,
        bytes32 exclusiveRelayer_,
        bytes calldata message_,
        bytes calldata proof_
    ) private {
        bytes32[] memory topics = new bytes32[](4);
        topics[0] = V3SpokePoolInterface.FundsDeposited.selector;
        topics[1] = bytes32(block.chainid); // uint256 destinationChainId
        topics[2] = bytes32(depositId_);    // uint256 depositId
        topics[3] = depositor_;             // bytes32 depositor

        bytes memory data = abi.encode(
            _address32(givePoolAsset),      // bytes32 inputToken
            _address32(address(poolAsset)), // bytes32 outputToken
            inputAmount_,                   // uint256 inputAmount
            outputAmount_,                  // uint256 outputAmount
            // indexed                      // uint256 destinationChainId
            // indexed                      // uint256 depositId
            quoteTimestamp_,                // uint32  quoteTimestamp
            fillDeadline_,                  // uint32  fillDeadline
            exclusivityDeadline_,           // uint32  exclusivityDeadline
            // indexed                      // bytes32 depositor
            recipient_,                     // bytes32 recipient
            exclusiveRelayer_,              // bytes32 exclusiveRelayer
            message_                        // bytes   message
        );

        verifier.verifyEvent(giveChain, giveSpokePool, topics, data, proof_);
    }

    function _fillRelay(
        uint256 inputAmount_,
        uint256 outputAmount_,
        uint256 depositId_,
        uint32 fillDeadline_,
        uint32 exclusivityDeadline_,
        bytes32 depositor_,
        bytes32 recipient_,
        bytes32 exclusiveRelayer_,
        bytes calldata message_
    ) private {
        V3SpokePoolInterface.V3RelayData memory relayData = V3SpokePoolInterface.V3RelayData({
            depositor:           depositor_,                     // bytes32
            recipient:           recipient_,                     // bytes32
            exclusiveRelayer:    exclusiveRelayer_,              // bytes32
            inputToken:          _address32(givePoolAsset),      // bytes32
            outputToken:         _address32(address(poolAsset)), // bytes32
            inputAmount:         inputAmount_,                   // uint256
            outputAmount:        outputAmount_,                  // uint256
            originChainId:       giveChain,                      // uint256
            depositId:           depositId_,                     // uint256
            fillDeadline:        fillDeadline_,                  // uint32
            exclusivityDeadline: exclusivityDeadline_,           // uint32
            message:             message_                        // bytes
        });
        spokePool.fillRelay(
            relayData,           // V3RelayData relayData
            giveChain,           // uint256     repaymentChainId
            _address32(givePool) // bytes32     repaymentAddress
        );
    }

    function _address32(address value_) private pure returns (bytes32) {
        return bytes32(uint256(uint160(value_)));
    }
}
