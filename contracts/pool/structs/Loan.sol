// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

// Sync changes with `LoanHashLib`

struct Loan {
    uint256 giveChain;
    address giveProvider;
    address giveExecutor;
    uint256 giveRebalanceAssets;
    uint256 takeChain;
    address takeProvider;
    uint256 takeEnclaveAssets;
    uint256 takeDeadline;
    bytes32 providerDataHash;
}
