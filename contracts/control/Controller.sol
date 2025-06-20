// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {NativeReceiver} from "../util/receive/NativeReceiver.sol";

import {IController} from './interfaces/IController.sol';

contract Controller is IController, Ownable2Step, NativeReceiver {
    constructor(address initialOwner_)
        Ownable(initialOwner_)
    {}

    function execute(address target_, bytes calldata data_, uint256 value_) public payable override onlyOwner {
        Address.functionCallWithValue(target_, data_, value_);
    }
}
