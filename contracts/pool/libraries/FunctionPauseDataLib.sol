// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

library FunctionPauseDataLib {
    // Read

    function readPause(uint256 pauseData_, uint8 index_) internal pure returns (bool) {
        return pauseData_ & _pauseMask(index_) != 0;
    }

    // Write

    function writePause(uint256 pauseData_, uint8 index_) internal pure returns (uint256) {
        return pauseData_ | _pauseMask(index_);
    }

    function writeUnpause(uint256 pauseData_, uint8 index_) internal pure returns (uint256) {
        return pauseData_ & ~_pauseMask(index_);
    }

    // ---

    function _pauseMask(uint8 index_) private pure returns (uint256) {
        return 1 << index_;
    }
}
