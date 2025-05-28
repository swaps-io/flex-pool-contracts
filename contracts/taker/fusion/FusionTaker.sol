// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {AssetRescuer} from "../../rescue/AssetRescuer.sol";

import {Controllable} from "../../control/Controllable.sol";

import {IFusionTaker, IEventVerifier} from "./interfaces/IFusionTaker.sol";

import {FusionTakeData} from "./structs/FusionTakeData.sol";

contract FusionTaker is IFusionTaker, AssetRescuer, Controllable {
    IEventVerifier public immutable override verifier;

    constructor(
        IEventVerifier verifier_,
        address controller_
    )
        Controllable(controller_)
    {
        verifier = verifier_;
    }

    function identify(bytes calldata data_) public view override returns (bytes32 id) {
        FusionTakeData calldata takeData = _decodeData(data_);
        // TODO
    }

    function take(
        address caller_,
        uint256 assets_,
        uint256 rewardAssets_,
        uint256 giveAssets_,
        bytes32 id_,
        bytes calldata data_
    ) public payable override {
        FusionTakeData calldata takeData = _decodeData(data_);
        // TODO
    }

    // ---

    function _canCallRescue(address caller_) internal view override returns (bool) {
        return caller_ == controller;
    }

    function _canRescueAsset(address /* asset_ */) internal pure override returns (bool) {
        return true; // Not designed to hold asset after transaction
    }

    // ---

    function _decodeData(bytes calldata data_) private pure returns (FusionTakeData calldata takeData) {
        assembly { takeData := add(data_.offset, 32) } // solhint-disable-line no-inline-assembly
    }
}
