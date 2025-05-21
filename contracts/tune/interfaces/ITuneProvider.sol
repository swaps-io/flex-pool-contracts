// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {TuneProviderParams} from "../structs/TuneProviderParams.sol";
import {TuneProviderResult} from "../structs/TuneProviderResult.sol";

interface ITuneProvider {
    function tune(TuneProviderParams calldata params) external view returns (TuneProviderResult memory);
}
