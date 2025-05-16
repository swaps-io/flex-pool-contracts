// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IPoolTuner} from "../../pool/PoolTuner.sol";

interface ISimpleTuner is IPoolTuner {
    event ProtocolPercentUpdate(uint256 indexed oldPercent, uint256 indexed newPercent);

    error SameProtocolPercent(uint256 percent);

    function protocolPercent() external view returns (uint256);

    // Owner functionality

    function setProtocolPercent(uint256 percent) external;
}
