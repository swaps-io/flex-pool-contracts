// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {LoanState} from "../enums/LoanState.sol";

library LoanStateLib {
    uint256 private constant LOAN_STATE_BITS = 3;
    uint256 private constant LOAN_STATE_MASK = (1 << LOAN_STATE_BITS) - 1;

    function readState(uint256 stateData_) internal pure returns (LoanState) {
        return LoanState(stateData_ & LOAN_STATE_MASK);
    }

    function readEscrowValue(uint256 stateData_) internal pure returns (uint256) {
        return stateData_ >> LOAN_STATE_BITS;
    }

    function makeData(LoanState state_, uint256 escrowValue_) internal pure returns (uint256) {
        return uint256(state_) | escrowValue_ << LOAN_STATE_BITS;
    }
}
