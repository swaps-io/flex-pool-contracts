// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ITaker} from "../taker/interfaces/ITaker.sol";

struct TestTakeData {
    bytes32 id;
    address caller;
    uint256 assets;
    uint256 surplusAssets;
    uint256 giveAssets;
    uint256 value;
}

contract TestTaker is ITaker {
    error AlreadyTaken(bytes32 id);
    error InvalidCaller(address caller, address expectedCaller);
    error InvalidAssets(uint256 assets, uint256 expectedAssets);
    error InvalidSurplusAssets(uint256 assets, uint256 expectedAssets);
    error InvalidGiveAssets(uint256 assets, uint256 expectedAssets);
    error InvalidValue(uint256 value, uint256 expectedValue);

    mapping(bytes32 id => bool) public taken;

    function take(
        address caller_,
        uint256 assets_,
        uint256 surplusAssets_,
        uint256 giveAssets_,
        bytes calldata data_
    ) public payable override {
        TestTakeData calldata testData;
        assembly ("memory-safe") {
            testData := data_.offset
        }

        require(!taken[testData.id], AlreadyTaken(testData.id));
        taken[testData.id] = true;
        require(caller_ == testData.caller, InvalidCaller(caller_, testData.caller));
        require(assets_ == testData.assets, InvalidAssets(assets_, testData.assets));
        require(surplusAssets_ == testData.surplusAssets, InvalidSurplusAssets(surplusAssets_, testData.surplusAssets));
        require(giveAssets_ == testData.giveAssets, InvalidGiveAssets(giveAssets_, testData.giveAssets));
        require(msg.value == testData.value, InvalidValue(msg.value, testData.value));
    }
}
