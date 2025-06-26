// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ITransferReliefTuner} from "./ITransferReliefTuner.sol";
import {ITransferGiver} from "./ITransferGiver.sol";

interface ITransferReliefGiver is ITransferGiver {
    function tuner() external view returns (ITransferReliefTuner);
}
