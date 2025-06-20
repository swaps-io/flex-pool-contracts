// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

// Based on `src/v2/TokenMessengerV2.sol` of `circlefin/evm-cctp-contracts` (`release-2025-03-11T143015` tag -
// https://github.com/circlefin/evm-cctp-contracts/tree/6e7513cdb2bee6bb0cddf331fe972600fc5017c9).
// The repo is problematic to use as a submodule, so the interface essentials were simply copied to here.

interface ITokenMessengerV2 {
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    ) external;
}
