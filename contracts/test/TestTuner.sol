// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ITuner} from "../tuner/interfaces/ITuner.sol";

struct TestTuneData {
    uint256 assets;
    uint256 protocolAssets;
    int256 rebalanceAssets;
}

contract TestTuner is ITuner {
    error InvalidAssets(uint256 assets, uint256 expectedAssets);

    function tune(
        uint256 assets_,
        bytes calldata data_
    ) public pure override returns (
        uint256 protocolAssets,
        int256 rebalanceAssets
    ) {
        TestTuneData calldata testData = _decodeData(data_);
        require(assets_ == testData.assets, InvalidAssets(assets_, testData.assets));
        protocolAssets = testData.protocolAssets;
        rebalanceAssets = testData.rebalanceAssets;
    }

    function _decodeData(bytes calldata data_) private pure returns (TestTuneData calldata testData) {
        assembly { testData := data_.offset }
    }
}
