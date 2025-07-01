// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ILinearProtocol} from "../../util/protocol/interfaces/ILinearProtocol.sol";
import {ILinearRebalance} from "../../util/rebalance/interfaces/ILinearRebalance.sol";

import {IPoolAware} from "../../../pool/aware/interfaces/IPoolAware.sol";

import {ITuner} from "../../interfaces/ITuner.sol";

interface ILinearTuner is ITuner, ILinearProtocol, ILinearRebalance, IPoolAware {}
