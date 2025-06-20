// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {V3SpokePoolInterface} from "@across-protocol/contracts/contracts/interfaces/V3SpokePoolInterface.sol";

import {IPoolAware} from "../../../pool/aware/interfaces/IPoolAware.sol";

import {IAssetRescuer} from "../../../rescue/interfaces/IAssetRescuer.sol";

import {IControllable} from "../../../control/interfaces/IControllable.sol";

interface IAcrossTakerBase is IPoolAware, IAssetRescuer, IControllable {
    error InsufficientTakeAssets(uint256 assets, uint256 minAssets);
    error InsufficientGiveAssets(uint256 assets, uint256 minAssets);

    function spokePool() external view returns (V3SpokePoolInterface);

    function giveChain() external view returns (uint256);

    function givePool() external view returns (address);

    function givePoolAsset() external view returns (address);

    function giveDecimalsShift() external view returns (int256);
}
