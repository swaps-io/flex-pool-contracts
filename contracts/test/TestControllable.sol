// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {Controllable} from "../control/Controllable.sol";

import {AssetRescuer} from "../rescue/AssetRescuer.sol";

import {NativeReceiver} from "../util/receive/NativeReceiver.sol";

contract TestControllable is Controllable, AssetRescuer, NativeReceiver {
    event TestEvent();

    constructor(address controller_)
        Controllable(controller_)
    {}

    function testAnyone() public payable {
        emit TestEvent();
    }

    function testOnlyController() public payable onlyController {
        emit TestEvent();
    }

    // ---

    function _canCallRescue(address caller_) internal view override returns (bool) {
        return caller_ == controller;
    }

    function _canRescueAsset(address /* asset_ */) internal pure override returns (bool) {
        return true;
    }
}
