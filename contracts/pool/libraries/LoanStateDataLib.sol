// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {LoanGiveState} from "../enums/LoanGiveState.sol";
import {LoanTakeState} from "../enums/LoanTakeState.sol";

library LoanStateDataLib {
    uint256 private constant GIVE_STATE_BITS = 2;
    uint256 private constant GIVE_STATE_MASK = (1 << GIVE_STATE_BITS) - 1;

    uint256 private constant TAKE_STATE_BITS = 2;
    uint256 private constant TAKE_STATE_MASK = (1 << TAKE_STATE_BITS) - 1;

    uint256 private constant STATE_BITS = GIVE_STATE_BITS + TAKE_STATE_BITS;

    // Read

    function readGiveState(uint256 stateData_) internal pure returns (LoanGiveState) {
        return LoanGiveState(stateData_ & GIVE_STATE_MASK);
    }

    function readTakeState(uint256 stateData_) internal pure returns (LoanTakeState) {
        return LoanTakeState(stateData_ >> GIVE_STATE_BITS & TAKE_STATE_MASK);
    }

    function readEscrowValue(uint256 stateData_) internal pure returns (uint256) {
        return stateData_ >> STATE_BITS;
    }

    // Write

    function writeGiveState(uint256 stateData_, LoanGiveState giveState_) internal pure returns (uint256) {
        return makeData(giveState_, readTakeState(stateData_), readEscrowValue(stateData_));
    }

    function writeTakeState(uint256 stateData_, LoanTakeState takeState_) internal pure returns (uint256) {
        return makeData(readGiveState(stateData_), takeState_, readEscrowValue(stateData_));
    }

    function writeEscrowValue(uint256 stateData_, uint256 escrowValue_) internal pure returns (uint256) {
        return makeData(readGiveState(stateData_), readTakeState(stateData_), escrowValue_);
    }

    // Make

    function makeData(
        LoanGiveState giveState_,
        LoanTakeState takeState_,
        uint256 escrowValue_
    ) internal pure returns (uint256) {
        return uint256(giveState_) | uint256(takeState_) << GIVE_STATE_BITS | escrowValue_ << STATE_BITS;
    }
}
