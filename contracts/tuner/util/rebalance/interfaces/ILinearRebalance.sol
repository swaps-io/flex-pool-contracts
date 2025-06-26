// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

interface ILinearRebalance {
    function rebalanceFixed() external view returns (uint256);

    function rebalancePercent() external view returns (uint256);
}
