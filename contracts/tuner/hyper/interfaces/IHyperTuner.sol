// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ILinearProtocol} from "../../util/protocol/interfaces/ILinearProtocol.sol";
import {ILinearRebalance} from "../../util/rebalance/interfaces/ILinearRebalance.sol";
import {IExtraRelief} from "../../util/relief/interfaces/IExtraRelief.sol";

import {IPoolAware} from "../../../pool/aware/interfaces/IPoolAware.sol";

import {IControllable} from "../../../control/interfaces/IControllable.sol";

import {ITuner} from "../../interfaces/ITuner.sol";

interface IHyperTuner is ITuner, ILinearProtocol, ILinearRebalance, IExtraRelief, IPoolAware, IControllable {
    event RelieverEnabled(address indexed reliever);
    event RelieverDisabled(address indexed reliever);

    error CallerNotReliever(address caller);
    error RelieverAlreadyEnabled(address reliever);
    error RelieverAlreadyDisabled(address reliever);

    function relieverEnabled(address reliever) external view returns (bool);

    function enableReliever(address reliever) external; // Only controller

    function disableReliever(address reliever) external; // Only controller
}
