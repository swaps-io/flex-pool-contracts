// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

interface ITuner {
    function tune(uint256 assets) external view returns (uint256 protocolAssets, int256 rebalanceAssets);
}
