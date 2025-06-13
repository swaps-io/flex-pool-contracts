// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IAcrossBaseTaker} from "./IAcrossBaseTaker.sol";

interface IAcrossDepositTaker is IAcrossBaseTaker {
    function takeToDeposit(
        uint256 assets,
        uint256 inputAmount,
        uint256 outputAmount,
        bytes32 exclusiveRelayer
    ) external;
}
