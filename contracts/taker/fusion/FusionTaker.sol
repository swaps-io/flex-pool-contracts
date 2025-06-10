// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IEscrowDst} from "@1inch/cross-chain-swap/contracts/interfaces/IEscrowDst.sol";
import {TimelocksLib} from "@1inch/cross-chain-swap/contracts/libraries/TimelocksLib.sol";

import {AddressLib, Address} from "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";

import {VerifierAware, IEventVerifier} from "../../verifier/aware/VerifierAware.sol";

import {DecimalsLib} from "../../util/libraries/DecimalsLib.sol";

import {IFusionTaker, IBaseEscrow, IEscrowFactory} from "./interfaces/IFusionTaker.sol";

import {FusionBase, IFlexPool} from "./FusionBase.sol";

contract FusionTaker is IFusionTaker, FusionBase, VerifierAware {
    uint256 public immutable override giveChain;
    address public immutable override giveEscrowFactory;
    address public immutable override giveFusionGiver;
    int256 public immutable override giveDecimalsShift;

    constructor(
        IFlexPool pool_,
        address controller_,
        address escrowFactory_,
        IEventVerifier verifier_,
        uint256 giveChain_,
        address giveEscrowFactory_,
        address giveFusionGiver_,
        int256 giveDecimalsShift_
    )
        FusionBase(pool_, controller_, escrowFactory_)
        VerifierAware(verifier_)
    {
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
        uint256 assets_,
        IBaseEscrow.Immutables calldata srcImmutables_,
        IEscrowFactory.DstImmutablesComplement calldata dstImmutablesComplement_,
        bytes calldata srcEscrowCreatedProof_
    ) public override payable
        trackNative
        trackToken(poolAsset)
    {
        uint256 balanceBefore = poolAsset.balanceOf(address(this));
        uint256 minGiveAssets = pool.take(assets_);
        uint256 takerAssets = poolAsset.balanceOf(address(this)) - balanceBefore;

        _verifySrcImmutables(srcImmutables_, minGiveAssets);
        _verifyDstImmutablesComplement(dstImmutablesComplement_, takerAssets);
        _verifyGiveEvent(srcImmutables_, dstImmutablesComplement_, srcEscrowCreatedProof_);

        IBaseEscrow.Immutables memory immutables = _composeDstImmutables(
            srcImmutables_,
            dstImmutablesComplement_
        );
        uint256 srcCancelTime = TimelocksLib.get(srcImmutables_.timelocks, TimelocksLib.Stage.SrcCancellation);
        IEscrowFactory(escrowFactory).createDstEscrow{value: msg.value}(immutables, srcCancelTime);
        _saveOriginalTaker(immutables, msg.sender);
    }

    // `IEscrowDst` compatibility

    function withdraw(bytes32 secret_, IBaseEscrow.Immutables calldata immutables_) public override {
        withdrawEscrow(_predictEscrow(immutables_), secret_, immutables_);
    }

    function cancel(IBaseEscrow.Immutables calldata immutables_) public override {
        cancelEscrow(_predictEscrow(immutables_), immutables_);
    }

    // `IEscrowDst` using pre-calculated address

    function withdrawEscrow(
        address escrow_,
        bytes32 secret_,
        IBaseEscrow.Immutables calldata immutables_
    ) public override
        onlyOriginalTaker(escrow_)
        trackNative
        trackToken(poolAsset)
    {
        IEscrowDst(escrow_).withdraw(secret_, immutables_);
    }

    function cancelEscrow(address escrow_, IBaseEscrow.Immutables calldata immutables_) public override
        trackNative
        returnPoolAsset
    {
        IEscrowDst(escrow_).cancel(immutables_);
    }

    // ---

    function _predictEscrow(IBaseEscrow.Immutables memory immutables_) internal view override returns (address) {
        return IEscrowFactory(escrowFactory).addressOfEscrowDst(immutables_);
    }

    // ---

    function _verifySrcImmutables(IBaseEscrow.Immutables calldata srcImmutables_, uint256 minAssets_) private view {
        require(
            AddressLib.get(srcImmutables_.taker) == giveFusionGiver,
            SrcImmutablesTakerNotFusionGiver(AddressLib.get(srcImmutables_.taker), giveFusionGiver)
        );

        (uint256 commonMinAssets, uint256 commonAssets) = DecimalsLib.common(
            minAssets_,
            srcImmutables_.amount,
            giveDecimalsShift
        );
        require(commonAssets >= commonMinAssets, InsufficientSrcImmutablesAssets(commonAssets, commonMinAssets));
    }

    function _verifyDstImmutablesComplement(
        IEscrowFactory.DstImmutablesComplement calldata dstImmutablesComplement_,
        uint256 takerAssets_
    ) private view {
        require(
            dstImmutablesComplement_.chainId == block.chainid,
            DstImmutablesComplementChainMismatch(dstImmutablesComplement_.chainId, block.chainid)
        );
        require(
            AddressLib.get(dstImmutablesComplement_.token) == address(poolAsset),
            DstImmutablesComplementAssetNotPool(AddressLib.get(dstImmutablesComplement_.token), address(poolAsset))
        );
        require(
            dstImmutablesComplement_.amount <= takerAssets_,
            ExcessiveDstImmutablesComplementAssets(dstImmutablesComplement_.amount, takerAssets_)
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
    ) private view returns (IBaseEscrow.Immutables memory immutables) {
        immutables.orderHash = srcImmutables_.orderHash;
        immutables.hashlock = srcImmutables_.hashlock;
        immutables.maker = dstImmutablesComplement_.maker;
        immutables.taker = Address.wrap(uint160(address(this)));
        immutables.token = dstImmutablesComplement_.token;
        immutables.amount = dstImmutablesComplement_.amount;
        immutables.safetyDeposit = dstImmutablesComplement_.safetyDeposit;
        immutables.timelocks = srcImmutables_.timelocks; // Updated w/ `setDeployedAt` by factory
    }
}
