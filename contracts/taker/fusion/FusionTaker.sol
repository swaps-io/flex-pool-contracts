// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {VerifierAware, IEventVerifier} from "../../verifier/aware/VerifierAware.sol";

import {AssetRescuer} from "../../rescue/AssetRescuer.sol";

import {Controllable} from "../../control/Controllable.sol";

import {IFusionTaker} from "./interfaces/IFusionTaker.sol";

import {FusionTakeData, IEscrowFactory, IBaseEscrow} from "./structs/FusionTakeData.sol";

contract FusionTaker is IFusionTaker, PoolAware, VerifierAware, AssetRescuer, Controllable {
    uint256 public immutable override srcEscrowChain;
    address public immutable override srcEscrowFactory;

    constructor(
        IFlexPool pool_,
        IEventVerifier verifier_,
        address controller_,
        uint256 srcEscrowChain_,
        address srcEscrowFactory_
    )
        PoolAware(pool_)
        VerifierAware(verifier_)
        Controllable(controller_)
    {
        srcEscrowChain = srcEscrowChain_;
        srcEscrowFactory = srcEscrowFactory_;
    }

    function take(
        address /* caller_ */,
        uint256 /* assets_ */,
        uint256 /* rewardAssets_ */,
        uint256 /* giveAssets_ */,
        bytes calldata data_
    ) public payable override onlyPool {
        FusionTakeData calldata takeData;
        assembly ("memory-safe") { // solhint-disable-line no-inline-assembly
            takeData := add(data_.offset, 32)
        }

        _verifyGiveEvent(takeData.srcImmutables, takeData.dstImmutablesComplement, takeData.srcEscrowCreatedProof);
        // TODO: implement
    }

    // ---

    function _canCallRescue(address caller_) internal view override returns (bool) {
        return caller_ == controller;
    }

    function _canRescueAsset(address /* asset_ */) internal pure override returns (bool) {
        return true; // Not designed to hold asset after transaction
    }

    // ---

    function _verifyGiveEvent(
        IBaseEscrow.Immutables calldata srcImmutables_,
        IEscrowFactory.DstImmutablesComplement calldata dstImmutablesComplement_,
        bytes memory proof_
    ) private {
        bytes32[] memory topics = new bytes32[](1);
        topics[0] = IEscrowFactory.SrcEscrowCreated.selector;
        bytes memory data = abi.encode(srcImmutables_, dstImmutablesComplement_);
        verifier.verifyEvent(srcEscrowChain, srcEscrowFactory, topics, data, proof_);
    }
}
