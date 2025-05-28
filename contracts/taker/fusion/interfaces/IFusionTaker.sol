// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IAssetRescuer} from "../../../rescue/interfaces/IAssetRescuer.sol";

import {IControllable} from "../../../control/interfaces/IControllable.sol";

import {IEventVerifier} from "../../../verifier/interfaces/IEventVerifier.sol";

import {ITaker} from "../../interfaces/ITaker.sol";

interface IFusionTaker is ITaker, IAssetRescuer, IControllable {
    function verifier() external view returns (IEventVerifier);
}
