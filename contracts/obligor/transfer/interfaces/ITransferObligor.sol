// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IPoolObligor} from "../../pool/interfaces/IPoolObligor.sol";

interface ITransferObligor is IPoolObligor {
    error InsufficientTransfer(uint256 assets, uint256 minAssets);
}
