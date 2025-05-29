// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {VerifierAware, IEventVerifier} from "../../verifier/aware/VerifierAware.sol";

import {AssetRescuer} from "../../rescue/AssetRescuer.sol";

import {Controllable} from "../../control/Controllable.sol";

import {IFusionTaker} from "./interfaces/IFusionTaker.sol";

import {FusionTakeData} from "./structs/FusionTakeData.sol";

contract FusionTaker is IFusionTaker, PoolAware, VerifierAware, AssetRescuer, Controllable {
    constructor(
        IFlexPool pool_,
        IEventVerifier verifier_,
        address controller_
    )
        PoolAware(pool_)
        VerifierAware(verifier_)
        Controllable(controller_)
    {
        verifier = verifier_;
    }

    function take(
        address /* caller_ */,
        uint256 /* assets_ */,
        uint256 /* rewardAssets_ */,
        uint256 /* giveAssets_ */,
        bytes calldata data_
    ) public payable override onlyPool {
        FusionTakeData calldata takeData;
        assembly { takeData := add(data_.offset, 32) } // solhint-disable-line no-inline-assembly

        // TODO: implement escrow logic
        // TODO: consider taken storage logic
    }

    // ---

    function _canCallRescue(address caller_) internal view override returns (bool) {
        return caller_ == controller;
    }

    function _canRescueAsset(address /* asset_ */) internal pure override returns (bool) {
        return true; // Not designed to hold asset after transaction
    }
}
