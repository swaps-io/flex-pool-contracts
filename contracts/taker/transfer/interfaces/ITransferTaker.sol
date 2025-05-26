// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {IEventVerifier} from "../../../verifier/interfaces/IEventVerifier.sol";

import {ITaker} from "../../interfaces/ITaker.sol";

interface ITransferTaker is ITaker {
    error InsufficientGiveAssets(uint256 assets, uint256 minAssets);

    function asset() external view returns (IERC20);

    function verifier() external view returns (IEventVerifier);

    function giveChain() external view returns (uint256);

    function transferGiver() external view returns (address);
}
