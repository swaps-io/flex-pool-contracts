// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ITuner} from "../tuner/interfaces/ITuner.sol";

import {IExtraRelief} from "../tuner/util/relief/interfaces/IExtraRelief.sol";

struct TestTuneData {
    uint256 assets;
    uint256 protocolAssets;
    int256 rebalanceAssets;
}

contract TestTuner is ITuner, IExtraRelief {
    error InvalidAssets(uint256 assets, uint256 expectedAssets);
    error InvalidExtraReliefAssets(uint256 assets, uint256 expectedAssets);

    uint256 public transient override extraReliefAssets;

    uint256 public expectedAssets;
    uint256 public expectedExtraReliefAssets;

    uint256 public protocolAssets;
    int256 public rebalanceAssets;

    function tune(uint256 assets_) public view override returns (uint256, int256) {
        require(assets_ == expectedAssets, InvalidAssets(assets_, expectedAssets));
        require(
            extraReliefAssets == expectedExtraReliefAssets,
            InvalidExtraReliefAssets(extraReliefAssets, expectedExtraReliefAssets)
        );
        return (protocolAssets, rebalanceAssets);
    }

    function setExpectedAssets(uint256 assets_) public {
        expectedAssets = assets_;
    }

    function setProtocolAssets(uint256 assets_) public {
        protocolAssets = assets_;
    }

    function setRebalanceAssets(int256 assets_) public {
        rebalanceAssets = assets_;
    }

    function setExtraReliefAssets(uint256 assets_) public override {
        extraReliefAssets = assets_;
    }

    function setExpectedExtraReliefAssets(uint256 assets_) public {
        expectedExtraReliefAssets = assets_;
    }
}
