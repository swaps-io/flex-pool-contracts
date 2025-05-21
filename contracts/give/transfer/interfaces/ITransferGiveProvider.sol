// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IPoolAware} from "../../../aware/interfaces/IPoolAware.sol";

import {IGiveProvider} from "../../interfaces/IGiveProvider.sol";

interface ITransferGiveProvider is IGiveProvider, IPoolAware {}
