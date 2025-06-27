// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IElasticTuner} from "../tuner/elastic/interfaces/IElasticTuner.sol";

contract TestElasticRelief {
    error InvalidExtraReliefAssets(uint256 assets, uint256 expectedAssets);
    error InvalidExtraReliefSetter(address setter, address expectedSetter);

    IElasticTuner public immutable tuner;

    constructor(IElasticTuner tuner_) {
        tuner = tuner_;
    }

    function testSetExtraReliefAssets(uint256 assets_) public {
        tuner.setExtraReliefAssets(assets_);
        require(
            tuner.extraReliefAssets() == assets_,
            InvalidExtraReliefAssets(tuner.extraReliefAssets(), assets_)
        );
        require(
            tuner.extraReliefSetter() == address(this),
            InvalidExtraReliefSetter(tuner.extraReliefSetter(), address(this))
        );
    }
}
