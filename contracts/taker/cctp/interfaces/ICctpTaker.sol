// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IPoolAware} from "../../../pool/aware/interfaces/IPoolAware.sol";

import {IAssetRescuer} from "../../../rescue/interfaces/IAssetRescuer.sol";

import {IControllable} from "../../../control/interfaces/IControllable.sol";

import {ITokenMessengerV2} from "./ITokenMessengerV2.sol";

interface ICctpTaker is IPoolAware, IAssetRescuer, IControllable {
    error InsufficientTakeAssets(uint256 assets, uint256 minAssets);
    error InsufficientGiveAssets(uint256 assets, uint256 minAssets);
    error ExcessiveCctpFee(uint256 amount, uint256 maxAmount);

    function tokenMessenger() external view returns (ITokenMessengerV2);

    function giveDomain() external view returns (uint32);

    function givePool() external view returns (address);

    function takeToBurn(uint256 assets, uint256 cctpAmount, uint256 cctpMaxFee) external;
}
