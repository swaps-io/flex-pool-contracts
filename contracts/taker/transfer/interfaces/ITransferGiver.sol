// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {IAssetPermitter} from "../../../permit/interfaces/IAssetPermitter.sol";

import {IAssetRescuer} from "../../../rescue/interfaces/IAssetRescuer.sol";

import {IControllable} from "../../../control/interfaces/IControllable.sol";

interface ITransferGiver is IAssetPermitter, IAssetRescuer, IControllable {
    event TransferGive(bytes32 indexed giveHash);

    function asset() external view returns (IERC20);

    function pool() external view returns (address);

    function give(uint256 assets, uint256 takeChain, address takeReceiver) external;

    function giveHold(uint256 assets, uint256 takeChain, address takeReceiver) external;
}
