// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IPoolAware} from "../../../pool/aware/interfaces/IPoolAware.sol";

import {ITuner} from "../../interfaces/ITuner.sol";

interface ILinearTuner is ITuner, IPoolAware {
    function protocolFixed() external view returns (uint256);

    function protocolPercent() external view returns (uint256);

    function rebalanceFixed() external view returns (uint256);

    function rebalancePercent() external view returns (uint256);
}
