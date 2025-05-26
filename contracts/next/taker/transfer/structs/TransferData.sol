// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

struct TransferData {
    uint256 giveAssets;
    uint256 giveBlock;
    address takeReceiver;
    bytes giveProof;
}
