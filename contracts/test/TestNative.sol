// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {NativeReceiver} from "../util/receive/NativeReceiver.sol";

contract TestNative is NativeReceiver {
    event TestResult(uint256 value);

    function testValueBalance() public payable {
        uint256 balance = address(this).balance - msg.value;
        emit TestResult(balance);
    }

    function testValueAccess() public {
        emit TestResult(_msgValue());
    }

    function _msgValue() private view returns (uint256) {
        return msg.value;
    }
}
