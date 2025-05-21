// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

library TakeDeadlineLib {
    uint256 private constant TAKE_DEADLINE_BITS = 128;
    uint256 private constant TAKE_DEADLINE_MASK = (1 << TAKE_DEADLINE_BITS) - 1;

    function readTakeDeadline(uint256 takeDeadline_) internal pure returns (uint256) {
        return takeDeadline_ & TAKE_DEADLINE_MASK;
    }

    function readExclusiveCancelTime(uint256 takeDeadline_) internal pure returns (uint256) {
        return takeDeadline_ >> TAKE_DEADLINE_BITS;
    }

    function readExclusiveCancelDeadline(uint256 takeDeadline_) internal pure returns (uint256) {
        return readTakeDeadline(takeDeadline_) + readExclusiveCancelTime(takeDeadline_);
    }
}
