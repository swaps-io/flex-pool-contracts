// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

contract TestPool {
    int256 public equilibriumAssets;
    uint256 public rebalanceReserveAssets;

    function setEquilibriumAssets(int256 assets_) public {
        equilibriumAssets = assets_;
    }

    function setRebalanceReserveAssets(uint256 assets_) public {
        rebalanceReserveAssets = assets_;
    }
}
