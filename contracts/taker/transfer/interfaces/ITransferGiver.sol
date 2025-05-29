// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IPoolAware} from "../../../pool/aware/interfaces/IPoolAware.sol";

import {IAssetPermitter} from "../../../permit/interfaces/IAssetPermitter.sol";

import {IAssetRescuer} from "../../../rescue/interfaces/IAssetRescuer.sol";

import {IControllable} from "../../../control/interfaces/IControllable.sol";

interface ITransferGiver is IPoolAware, IAssetPermitter, IAssetRescuer, IControllable {
    event TransferGive(uint256 assets, uint256 takeChain, address takeReceiver, uint256 takeNonce);

    function give(uint256 assets, uint256 takeChain, address takeReceiver, uint256 takeNonce) external;

    function giveHold(uint256 assets, uint256 takeChain, address takeReceiver, uint256 takeNonce) external;
}
