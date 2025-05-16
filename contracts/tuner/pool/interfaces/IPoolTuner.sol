// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IFlexPool} from "../../../pool/interfaces/IFlexPool.sol";

import {ITuner} from "../../interfaces/ITuner.sol";

interface IPoolTuner is ITuner {
    function pool() external view returns (IFlexPool);
}
