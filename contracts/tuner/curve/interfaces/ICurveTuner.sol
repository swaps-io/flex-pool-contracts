// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IPoolAware} from "../../../pool/aware/interfaces/IPoolAware.sol";

import {IControllable} from "../../../control/interfaces/IControllable.sol";

import {ITuner} from "../../interfaces/ITuner.sol";

interface ICurveTuner is ITuner, IPoolAware, IControllable {
    event EquilibriumShifterEnabled(address indexed shifter);
    event EquilibriumShifterDisabled(address indexed shifter);

    error CallerNotEquilibriumShifter(address caller);
    error EquilibriumShifterAlreadyEnabled(address shifter);
    error EquilibriumShifterAlreadyDisabled(address shifter);

    function protocolFixed() external view returns (uint256);

    function protocolPercent() external view returns (uint256);

    function rebalanceFixed() external view returns (uint256);

    function rebalancePercent() external view returns (uint256);

    function equilibriumShift() external view returns (int256);

    function equilibriumShifter(address shifter) external view returns (bool);

    function setEquilibriumShift(int256 assets) external; // Only shifter

    function enableEquilibriumShifter(address shifter) external; // Only controller

    function disableEquilibriumShifter(address shifter) external; // Only controller
}
