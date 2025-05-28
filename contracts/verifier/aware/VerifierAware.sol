// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IVerifierAware, IEventVerifier} from "./interfaces/IVerifierAware.sol";

abstract contract VerifierAware is IVerifierAware {
    IEventVerifier public immutable override verifier;

    constructor(IEventVerifier verifier_) {
        verifier = verifier_;
    }
}
