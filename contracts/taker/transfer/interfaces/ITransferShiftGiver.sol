// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IEquilibriumShift} from "../../../tuner/util/equilibrium/interfaces/IEquilibriumShift.sol";

import {ITransferGiver} from "./ITransferGiver.sol";

interface ITransferShiftGiver is ITransferGiver {
    error InsufficientTakeSurplus(uint256 assets, uint256 minAssets);

    function tuner() external view returns (IEquilibriumShift);
}
