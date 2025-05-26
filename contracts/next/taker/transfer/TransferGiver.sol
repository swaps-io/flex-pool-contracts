// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {AssetPermitter} from "../../../permit/AssetPermitter.sol";

import {ITransferGiver, IERC20} from "./interfaces/ITransferGiver.sol";

import {TransferGiveHashLib} from "./libraries/TransferGiveHashLib.sol";

contract TransferGiver is ITransferGiver, AssetPermitter {
    IERC20 public immutable override asset;
    address public immutable override pool;

    constructor(IERC20 asset_, address pool_)
        AssetPermitter(asset_)
    {
        asset = asset_;
        pool = pool_;
    }

    function give(uint256 assets_, uint256 takeChain_, address takeReceiver_) public override {
        SafeERC20.safeTransferFrom(asset, msg.sender, pool, assets_);
        _emitGiveEvent(assets_, takeChain_, takeReceiver_);
    }

    function giveOwn(uint256 assets_, uint256 takeChain_, address takeReceiver_) public override {
        SafeERC20.safeTransfer(asset, pool, assets_);
        _emitGiveEvent(assets_, takeChain_, takeReceiver_);
    }

    function _emitGiveEvent(uint256 assets_, uint256 takeChain_, address takeReceiver_) private {
        bytes32 giveHash = TransferGiveHashLib.calc(assets_, block.number, takeChain_, takeReceiver_);
        emit TransferGive(giveHash);
    }
}
