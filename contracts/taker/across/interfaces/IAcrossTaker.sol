// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {V3SpokePoolInterface} from "@across-protocol/contracts/contracts/interfaces/V3SpokePoolInterface.sol";

import {IPoolAware} from "../../../pool/aware/interfaces/IPoolAware.sol";

import {IVerifierAware} from "../../../verifier/aware/interfaces/IVerifierAware.sol";

import {IAssetRescuer} from "../../../rescue/interfaces/IAssetRescuer.sol";

import {IControllable} from "../../../control/interfaces/IControllable.sol";

interface IAcrossTaker is IPoolAware, IVerifierAware, IAssetRescuer, IControllable {
    error InsufficientTakeAssets(uint256 assets, uint256 minAssets);
    error InsufficientGiveAssets(uint256 assets, uint256 minAssets);
    error AlreadyTaken(address receiver, uint256 nonce);

    function spokePool() external view returns (V3SpokePoolInterface);

    function giveChain() external view returns (uint256);

    function givePool() external view returns (address);

    function givePoolAsset() external view returns (address);

    function giveSpokePool() external view returns (address);

    function giveDecimalsShift() external view returns (int256);

    function takeToFillRelay(
        uint256 assets,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 depositId,
        uint32 quoteTimestamp,
        uint32 fillDeadline,
        uint32 exclusivityDeadline,
        bytes32 depositor,
        bytes32 recipient,
        bytes32 exclusiveRelayer,
        bytes calldata message,
        bytes calldata depositProof
    ) external;
}
