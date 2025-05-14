// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

interface IEventVerifier {
    function verifyEvent(
        uint256 chain,
        address emitter,
        bytes32[] calldata topics,
        bytes calldata data,
        bytes calldata proof
    ) external;
}
