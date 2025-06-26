// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ITuner} from "../../../tuner/interfaces/ITuner.sol";

import {IExtraRelief} from "../../../tuner/util/relief/interfaces/IExtraRelief.sol";

interface ITransferReliefTuner is ITuner, IExtraRelief {}
