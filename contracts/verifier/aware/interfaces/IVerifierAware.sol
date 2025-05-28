// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IEventVerifier} from "../../../verifier/interfaces/IEventVerifier.sol";

interface IVerifierAware {
    function verifier() external view returns (IEventVerifier);
}
