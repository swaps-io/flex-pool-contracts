// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IEventVerifier} from "../verifier/interfaces/IEventVerifier.sol";

contract TestVerifier is IEventVerifier {
    error InvalidEvent(bytes32 eventHash, uint256 chain, address emitter, bytes32[] topics, bytes data, bytes proof);

    mapping(bytes32 eventHash => bool) eventVerified;

    function verifyEvent(
        uint256 chain_,
        address emitter_,
        bytes32[] calldata topics_,
        bytes calldata data_,
        bytes calldata proof_
    ) public view override {
        bytes32 eventHash = _calcEventHash(chain_, emitter_, topics_, data_, proof_);
        require(eventVerified[eventHash], InvalidEvent(eventHash, chain_, emitter_, topics_, data_, proof_));
    }

    function setEventVerified(
        uint256 chain_,
        address emitter_,
        bytes32[] calldata topics_,
        bytes calldata data_,
        bytes calldata proof_,
        bool verified_
    ) public {
        bytes32 eventHash = _calcEventHash(chain_, emitter_, topics_, data_, proof_);
        eventVerified[eventHash] = verified_;
    }

    function _calcEventHash(
        uint256 chain_,
        address emitter_,
        bytes32[] calldata topics_,
        bytes calldata data_,
        bytes calldata proof_
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(chain_, emitter_, topics_, data_, proof_));
    }
}
