// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

struct GiveParams {
    address tuneProvider;
    address giveProvider;
    address giveExecutor;
    uint256 takeChain;
    uint256 takeAssets;
    uint256 takeDeadline;
    bytes providerData;
    bytes tuneExtraData;
}
