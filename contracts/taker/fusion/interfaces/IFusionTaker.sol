// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IPoolAware} from "../../../pool/aware/interfaces/IPoolAware.sol";

import {IVerifierAware} from "../../../verifier/aware/interfaces/IVerifierAware.sol";

import {IAssetRescuer} from "../../../rescue/interfaces/IAssetRescuer.sol";

import {IControllable} from "../../../control/interfaces/IControllable.sol";

import {ITaker} from "../../interfaces/ITaker.sol";

interface IFusionTaker is ITaker, IPoolAware, IVerifierAware, IAssetRescuer, IControllable {
    error SrcImmutablesTakerNotFusionGiver(address immutablesTaker, address fusionGiver);
    error DstImmutablesComplementChainMismatch(uint256 complementChainId, uint256 blockChainId);
    error DstImmutablesComplementAssetNotPool(address complementToken, address poolAsset);
    error InsufficientSrcImmutablesAssets(uint256 assets, uint256 minAssets);

    function escrowFactory() external view returns (address);

    function giveChain() external view returns (uint256);

    function giveEscrowFactory() external view returns (address);

    function giveFusionGiver() external view returns (address);

    function giveDecimalsShift() external view returns (int256);
}
