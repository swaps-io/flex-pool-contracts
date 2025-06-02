// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IVerifierAware} from "../../../verifier/aware/interfaces/IVerifierAware.sol";

import {ITaker} from "../../interfaces/ITaker.sol";

import {IFusionBase, IBaseEscrow} from "./IFusionBase.sol";

interface IFusionTaker is ITaker, IFusionBase, IVerifierAware {
    error SrcImmutablesTakerNotFusionGiver(address immutablesTaker, address fusionGiver);
    error DstImmutablesComplementChainMismatch(uint256 complementChainId, uint256 blockChainId);
    error DstImmutablesComplementAssetNotPool(address complementToken, address poolAsset);
    error InsufficientSrcImmutablesAssets(uint256 assets, uint256 minAssets);

    function giveChain() external view returns (uint256);

    function giveEscrowFactory() external view returns (address);

    function giveFusionGiver() external view returns (address);

    function giveDecimalsShift() external view returns (int256);

    // `IEscrowDst` compatibility

    function withdraw(bytes32 secret, IBaseEscrow.Immutables calldata immutables) external;

    function cancel(IBaseEscrow.Immutables calldata immutables) external;

    // `IEscrowDst` using pre-calculated address

    function withdrawEscrow(address escrow, bytes32 secret, IBaseEscrow.Immutables calldata immutables) external;

    function cancelEscrow(address escrow, IBaseEscrow.Immutables calldata immutables) external;
}
