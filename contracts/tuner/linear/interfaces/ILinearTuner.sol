// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IFlexPool} from "../../../pool/interfaces/IFlexPool.sol";

import {ITuner} from "../../interfaces/ITuner.sol";

interface ILinearTuner is ITuner {
    function pool() external view returns (IFlexPool);

    function protocolFixed() external view returns (uint256);

    function protocolPercent() external view returns (uint256);

    function rebalanceFixed() external view returns (uint256);

    function rebalancePercent() external view returns (uint256);
}
