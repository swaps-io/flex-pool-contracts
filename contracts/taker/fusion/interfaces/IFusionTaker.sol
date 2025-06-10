// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IBaseEscrow, IEscrowFactory} from "@1inch/cross-chain-swap/contracts/interfaces/IEscrowFactory.sol";

import {IVerifierAware} from "../../../verifier/aware/interfaces/IVerifierAware.sol";

import {IFusionBase} from "./IFusionBase.sol";

interface IFusionTaker is IFusionBase, IVerifierAware {
    error SrcImmutablesTakerNotFusionGiver(address immutablesTaker, address fusionGiver);
    error DstImmutablesComplementChainMismatch(uint256 complementChainId, uint256 blockChainId);
    error DstImmutablesComplementAssetNotPool(address complementToken, address poolAsset);
    error InsufficientSrcImmutablesAssets(uint256 assets, uint256 minAssets);
    error ExcessiveDstImmutablesComplementAssets(uint256 assets, uint256 maxAssets);

    function giveChain() external view returns (uint256);

    function giveEscrowFactory() external view returns (address);

    function giveFusionGiver() external view returns (address);

    function giveDecimalsShift() external view returns (int256);

    function take(
        uint256 assets,
        IBaseEscrow.Immutables calldata srcImmutables,
        IEscrowFactory.DstImmutablesComplement calldata dstImmutablesComplement,
        bytes calldata srcEscrowCreatedProof
    ) external payable;

    // `IEscrowDst` compatibility

    function withdraw(bytes32 secret, IBaseEscrow.Immutables calldata immutables) external;

    function cancel(IBaseEscrow.Immutables calldata immutables) external;

    // `IEscrowDst` using pre-calculated address

    function withdrawEscrow(address escrow, bytes32 secret, IBaseEscrow.Immutables calldata immutables) external;

    function cancelEscrow(address escrow, IBaseEscrow.Immutables calldata immutables) external;
}
