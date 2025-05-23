// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {Loan} from "../structs/Loan.sol";

library LoanHashLib {
    function calc(Loan memory loan_) internal pure returns (bytes32 hash) {
        assembly { hash := keccak256(loan_, 288) } // solhint-disable-line no-inline-assembly
    }
}
