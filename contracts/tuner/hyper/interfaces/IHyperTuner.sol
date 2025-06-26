// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ILinearProtocol} from "../../util/protocol/interfaces/ILinearProtocol.sol";
import {ILinearRebalance} from "../../util/rebalance/interfaces/ILinearRebalance.sol";
import {IEquilibriumShift} from "../../util/equilibrium/interfaces/IEquilibriumShift.sol";

import {IPoolAware} from "../../../pool/aware/interfaces/IPoolAware.sol";

import {IControllable} from "../../../control/interfaces/IControllable.sol";

import {ITuner} from "../../interfaces/ITuner.sol";

interface IHyperTuner is ITuner, ILinearProtocol, ILinearRebalance, IEquilibriumShift, IPoolAware, IControllable {
    event EquilibriumShifterEnabled(address indexed shifter);
    event EquilibriumShifterDisabled(address indexed shifter);

    error CallerNotEquilibriumShifter(address caller);
    error EquilibriumShifterAlreadyEnabled(address shifter);
    error EquilibriumShifterAlreadyDisabled(address shifter);

    function equilibriumShifter(address shifter) external view returns (bool);

    function enableEquilibriumShifter(address shifter) external; // Only controller

    function disableEquilibriumShifter(address shifter) external; // Only controller
}
