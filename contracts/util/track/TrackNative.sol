// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

abstract contract TrackNative {
    modifier trackNative {
        uint256 amountBefore = _trackNativeBefore();
        _;
        _trackNativeAfter(amountBefore);
    }

    function _trackNativeBefore() internal view returns (uint256 amountBefore) {
        return address(this).balance - msg.value;
    }

    function _trackNativeAfter(uint256 amountBefore_) internal {
        uint256 amountAfter = address(this).balance;
        if (amountAfter > amountBefore_) {
            Address.sendValue(payable(msg.sender), amountAfter - amountBefore_);
        }
    }
}
