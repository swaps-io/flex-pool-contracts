// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IAssetPermitter} from "../../../permit/AssetPermitter.sol";

import {IPoolObligor} from "../../pool/interfaces/IPoolObligor.sol";

interface ITransferObligor is IPoolObligor, IAssetPermitter {
    error InsufficientTransfer(uint256 assets, uint256 minAssets);
}
