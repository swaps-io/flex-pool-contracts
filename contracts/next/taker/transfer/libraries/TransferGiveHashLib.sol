// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

library TransferGiveHashLib {
    function calc(
        uint256 giveAssets_,
        uint256 giveBlock_,
        uint256 takeChain_,
        address takeReceiver_
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(giveAssets_, giveBlock_, takeChain_, takeReceiver_));
    }
}
