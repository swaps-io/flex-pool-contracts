// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IBaseEscrow} from "@1inch/cross-chain-swap/contracts/interfaces/IBaseEscrow.sol";
import {IEscrowSrc} from "@1inch/cross-chain-swap/contracts/interfaces/IEscrowSrc.sol";

import {IPoolAware} from "../../../pool/aware/interfaces/IPoolAware.sol";

import {IAssetPermitter} from "../../../permit/interfaces/IAssetPermitter.sol";

import {IAssetRescuer} from "../../../rescue/interfaces/IAssetRescuer.sol";

import {IControllable} from "../../../control/interfaces/IControllable.sol";

interface IFusionGiver is IPoolAware, IAssetPermitter, IAssetRescuer, IControllable {
    error NotFillOrderCall(bytes4 selector);
    error GiverAssetsAffected(uint256 assets, uint256 assetsBefore);

    function router() external view returns (address);

    function fill(uint256 assets, bytes calldata fillData) external payable;

    function withdraw(IEscrowSrc escrow, bytes32 secret, IBaseEscrow.Immutables calldata immutables) external;
}
