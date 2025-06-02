// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {TimelocksLib} from "@1inch/cross-chain-swap/contracts/libraries/TimelocksLib.sol";

import {AddressLib} from "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {VerifierAware, IEventVerifier} from "../../verifier/aware/VerifierAware.sol";

import {AssetRescuer} from "../../rescue/AssetRescuer.sol";

import {Controllable} from "../../control/Controllable.sol";

import {DecimalsLib} from "../../util/libraries/DecimalsLib.sol";
import {TrackToken} from "../../util/track/TrackToken.sol";

import {IFusionTaker} from "./interfaces/IFusionTaker.sol";

import {FusionTakeData, IEscrowFactory, IBaseEscrow} from "./structs/FusionTakeData.sol";

contract FusionTaker is IFusionTaker, PoolAware, VerifierAware, AssetRescuer, Controllable, TrackToken {
    address public immutable override escrowFactory;
    uint256 public immutable override giveChain;
    address public immutable override giveEscrowFactory;
    address public immutable override giveFusionGiver;
    int256 public immutable override giveDecimalsShift;

    constructor(
        IFlexPool pool_,
        IEventVerifier verifier_,
        address controller_,
        address escrowFactory_,
        uint256 giveChain_,
        address giveEscrowFactory_,
        address giveFusionGiver_,
        int256 giveDecimalsShift_
    )
        PoolAware(pool_)
        VerifierAware(verifier_)
        Controllable(controller_)
    {
        escrowFactory = escrowFactory_;
        giveChain = giveChain_;
        giveEscrowFactory = giveEscrowFactory_;
        giveFusionGiver = giveFusionGiver_;
        giveDecimalsShift = giveDecimalsShift_;

        // Provide infinite allowance to the factory. Any `msg.sender` interactions are limited by take logic below.
        // Contract is not designed to hold pool asset after transaction. Won't verify any contract signature nor allow
        // other ways to obtain permit.
        poolAsset.approve(escrowFactory, type(uint256).max);
    }

    function take(
        address caller_,
        uint256 /* assets_ */,
        uint256 /* rewardAssets_ */,
        uint256 giveAssets_,
        bytes calldata data_
    ) public payable override onlyPool {
        FusionTakeData calldata takeData;
        assembly ("memory-safe") { // solhint-disable-line no-inline-assembly
            takeData := add(data_.offset, 32)
        }

        _verifySrcImmutables(takeData.srcImmutables, giveAssets_);
        _verifyDstImmutablesComplement(takeData.dstImmutablesComplement);
        _verifyGiveEvent(takeData.srcImmutables, takeData.dstImmutablesComplement, takeData.srcEscrowCreatedProof);

        IEscrowFactory(escrowFactory).createDstEscrow{value: msg.value}(
            _composeDstImmutables(takeData.srcImmutables, takeData.dstImmutablesComplement),
            takeData.srcCancellationTimestamp
        );

        _trackTokenAfter(poolAsset, 0, caller_);
    }

    // ---

    function _canCallRescue(address caller_) internal view override returns (bool) {
        return caller_ == controller;
    }

    function _canRescueAsset(address /* asset_ */) internal pure override returns (bool) {
        return true; // Not designed to hold asset after transaction
    }

    // ---

    function _verifySrcImmutables(
        IBaseEscrow.Immutables calldata srcImmutables_,
        uint256 giveAssets_
    ) private view {
        require(
            AddressLib.get(srcImmutables_.taker) == giveFusionGiver,
            SrcImmutablesTakerNotFusionGiver(AddressLib.get(srcImmutables_.taker), giveFusionGiver)
        );
        // Fusion giver includes give `token` verification (it's valid if event is valid)

        (
            uint256 commonGiveAssets,
            uint256 commonImmutablesAssets
        ) = DecimalsLib.common(giveAssets_, srcImmutables_.amount, giveDecimalsShift);
        require(
            commonImmutablesAssets >= commonGiveAssets,
            InsufficientSrcImmutablesAssets(commonImmutablesAssets, commonGiveAssets)
        );
    }

    function _verifyDstImmutablesComplement(
        IEscrowFactory.DstImmutablesComplement calldata dstImmutablesComplement_
    ) private view {
        require(
            dstImmutablesComplement_.chainId == block.chainid,
            DstImmutablesComplementChainMismatch(dstImmutablesComplement_.chainId, block.chainid)
        );
        require(
            AddressLib.get(dstImmutablesComplement_.token) == address(poolAsset),
            DstImmutablesComplementAssetNotPool(AddressLib.get(dstImmutablesComplement_.token), address(poolAsset))
        );
    }

    function _verifyGiveEvent(
        IBaseEscrow.Immutables calldata srcImmutables_,
        IEscrowFactory.DstImmutablesComplement calldata dstImmutablesComplement_,
        bytes memory proof_
    ) private {
        bytes32[] memory topics = new bytes32[](1);
        topics[0] = IEscrowFactory.SrcEscrowCreated.selector;
        bytes memory data = abi.encode(srcImmutables_, dstImmutablesComplement_);
        verifier.verifyEvent(giveChain, giveEscrowFactory, topics, data, proof_);
    }

    function _composeDstImmutables(
        IBaseEscrow.Immutables calldata srcImmutables_,
        IEscrowFactory.DstImmutablesComplement calldata dstImmutablesComplement_
    ) private pure returns (IBaseEscrow.Immutables memory immutables) {
        immutables.orderHash = srcImmutables_.orderHash;
        immutables.hashlock = srcImmutables_.hashlock;
        immutables.maker = dstImmutablesComplement_.maker;
        immutables.taker = srcImmutables_.taker;
        immutables.token = dstImmutablesComplement_.token;
        immutables.amount = dstImmutablesComplement_.amount;
        immutables.safetyDeposit = dstImmutablesComplement_.safetyDeposit;
        immutables.timelocks = TimelocksLib.setDeployedAt(srcImmutables_.timelocks, 0);
    }
}
