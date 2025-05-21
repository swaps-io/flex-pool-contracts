// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

struct TuneProviderParams {
    address giveProvider;
    address giveExecutor;
    uint256 takeChain;
    address takeProvider;
    uint256 takeAssets;
    uint256 takeDeadline;
    bytes extraData;
}
