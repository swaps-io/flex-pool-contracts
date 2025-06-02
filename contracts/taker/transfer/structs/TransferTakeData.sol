// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

struct TransferTakeData {
    uint256 giveAssets;
    uint256 takeNonce;
    bytes giveProof;
}
