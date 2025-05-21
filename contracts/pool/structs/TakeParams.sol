// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

struct TakeParams {
    uint256 giveChain;
    address giveProvider;
    address giveExecutor;
    address takeProvider;
    uint256 takeAssets;
    uint256 takeDeadline;
    bytes providerData;
    bytes giveProof;
}
