// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

abstract contract TrackNative {
    modifier trackNative {
        uint256 amountBefore = _trackNativeBefore();
        _;
        _trackNativeAfter(amountBefore);
    }

    modifier trackNativeTo(address receiver_) {
        uint256 amountBefore = _trackNativeBefore();
        _;
        _trackNativeAfter(amountBefore, receiver_);
    }

    function _trackNativeBefore() internal view returns (uint256 amountBefore) {
        return address(this).balance - msg.value;
    }

    function _trackNativeAfter(uint256 amountBefore_) internal {
        _trackNativeAfter(amountBefore_, msg.sender);
    }

    function _trackNativeAfter(uint256 amountBefore_, address receiver_) internal {
        uint256 amountAfter = address(this).balance;
        if (amountAfter > amountBefore_) {
            Address.sendValue(payable(receiver_), amountAfter - amountBefore_);
        }
    }
}
