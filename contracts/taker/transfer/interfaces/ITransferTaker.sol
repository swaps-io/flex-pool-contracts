// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IPoolAware} from "../../../pool/aware/interfaces/IPoolAware.sol";

import {IVerifierAware} from "../../../verifier/aware/interfaces/IVerifierAware.sol";

import {IAssetRescuer} from "../../../rescue/interfaces/IAssetRescuer.sol";

import {IControllable} from "../../../control/interfaces/IControllable.sol";

import {ITaker} from "../../interfaces/ITaker.sol";

interface ITransferTaker is ITaker, IPoolAware, IVerifierAware, IAssetRescuer, IControllable {
    error CallerNotReceiver(address caller, address receiver);
    error InsufficientGiveAssets(uint256 assets, uint256 minAssets);
    error AlreadyTaken(address receiver, uint256 nonce);

    function giveChain() external view returns (uint256);

    function giveTransferGiver() external view returns (address);

    function giveDecimalsShift() external view returns (int256);

    function taken(address receiver, uint256 nonce) external view returns (bool);
}
