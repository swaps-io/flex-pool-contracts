// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {IAssetRescuer} from "../../../rescue/interfaces/IAssetRescuer.sol";

import {IControllable} from "../../../control/interfaces/IControllable.sol";

import {IEventVerifier} from "../../../verifier/interfaces/IEventVerifier.sol";

import {ITaker} from "../../interfaces/ITaker.sol";

interface ITransferTaker is ITaker, IAssetRescuer, IControllable {
    error InsufficientGiveAssets(uint256 assets, uint256 minAssets);

    function asset() external view returns (IERC20);

    function giveChain() external view returns (uint256);

    function giveTransferGiver() external view returns (address);

    function giveDecimalsShift() external view returns (int256);

    function verifier() external view returns (IEventVerifier);
}
