// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

contract TestNative {
    event TestResult(uint256 value);

    receive() external payable {}

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
