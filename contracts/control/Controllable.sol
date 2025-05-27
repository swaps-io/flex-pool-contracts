// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IControllable} from "./interfaces/IControllable.sol";

abstract contract Controllable is IControllable {
    address public immutable override controller;

    constructor(address controller_) {
        controller = controller_;
    }

    modifier onlyController {
        require(msg.sender == controller, CallerNotController(msg.sender, controller));
        _;
    }
}
