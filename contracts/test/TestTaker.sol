// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ITaker} from "../taker/interfaces/ITaker.sol";

struct TestTakeData {
    bytes32 id;
    address caller;
    uint256 assets;
    uint256 rewardAssets;
    uint256 giveAssets;
    uint256 value;
}

contract TestTaker is ITaker {
    error InvalidId(bytes32 id, bytes32 expectedId);
    error InvalidCaller(address caller, address expectedCaller);
    error InvalidAssets(uint256 assets, uint256 expectedAssets);
    error InvalidRewardAssets(uint256 assets, uint256 expectedAssets);
    error InvalidGiveAssets(uint256 assets, uint256 expectedAssets);
    error InvalidValue(uint256 value, uint256 expectedValue);

    function identify(bytes calldata data_) public pure override returns (bytes32 id) {
        TestTakeData calldata testData = _decodeData(data_);
        return testData.id;
    }

    function take(
        address caller_,
        uint256 assets_,
        uint256 rewardAssets_,
        uint256 giveAssets_,
        bytes32 id_,
        bytes calldata data_
    ) public payable override {
        TestTakeData calldata testData = _decodeData(data_);
        require(id_ == testData.id, InvalidId(id_, testData.id));
        require(caller_ == testData.caller, InvalidCaller(caller_, testData.caller));
        require(assets_ == testData.assets, InvalidAssets(assets_, testData.assets));
        require(rewardAssets_ == testData.rewardAssets, InvalidRewardAssets(rewardAssets_, testData.rewardAssets));
        require(giveAssets_ == testData.giveAssets, InvalidGiveAssets(giveAssets_, testData.giveAssets));
        require(msg.value == testData.value, InvalidValue(msg.value, testData.value));
    }

    function _decodeData(bytes calldata data_) private pure returns (TestTakeData calldata testData) {
        assembly { testData := data_.offset }
    }
}
