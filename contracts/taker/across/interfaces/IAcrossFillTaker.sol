// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IVerifierAware} from "../../../verifier/aware/interfaces/IVerifierAware.sol";

import {IAcrossTakerBase} from "./IAcrossTakerBase.sol";

interface IAcrossFillTaker is IAcrossTakerBase, IVerifierAware {
    function giveSpokePool() external view returns (address);

    function takeToFillRelay(
        uint256 assets,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 depositId,
        uint32 quoteTimestamp,
        uint32 fillDeadline,
        uint32 exclusivityDeadline,
        bytes32 depositor,
        bytes32 recipient,
        bytes32 exclusiveRelayer,
        bytes calldata message,
        bytes calldata depositProof
    ) external;
}
