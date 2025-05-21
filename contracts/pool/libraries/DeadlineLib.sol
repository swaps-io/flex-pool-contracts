// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

library DeadlineLib {
    function time() internal view returns (uint256) {
        return block.timestamp;
    }

    function active(uint256 deadline_) internal view returns (bool) {
        return time() <= deadline_;
    }

    function remain(uint256 deadline_) internal view returns (uint256) {
        return deadline_ - time();
    }
}
