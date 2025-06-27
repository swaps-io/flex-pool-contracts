// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

contract TestPool {
    address public asset;
    uint256 public totalAssets;
    int256 public equilibriumAssets;
    uint256 public rebalanceAssets;

    function setAsset(address asset_) public {
        asset = asset_;
    }

    function setTotalAssets(uint256 assets_) public {
        totalAssets = assets_;
    }

    function setEquilibriumAssets(int256 assets_) public {
        equilibriumAssets = assets_;
    }

    function setRebalanceAssets(uint256 assets_) public {
        rebalanceAssets = assets_;
    }
}
