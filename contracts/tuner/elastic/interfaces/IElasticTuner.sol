// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ILinearProtocol} from "../../util/protocol/interfaces/ILinearProtocol.sol";
import {ILinearRebalance} from "../../util/rebalance/interfaces/ILinearRebalance.sol";
import {IExtraRelief} from "../../util/relief/interfaces/IExtraRelief.sol";

import {IPoolAware} from "../../../pool/aware/interfaces/IPoolAware.sol";

import {ITuner} from "../../interfaces/ITuner.sol";

interface IElasticTuner is ITuner, ILinearProtocol, ILinearRebalance, IExtraRelief, IPoolAware {
    error InvalidExtraReliefSetter(address setter, address tuner);

    function extraReliefSetter() external view returns (address);

    function tuneRelief(
        uint256 assets,
        uint256 relief
    ) external view returns (
        uint256 protocolAssets,
        int256 rebalanceAssets
    );
}
