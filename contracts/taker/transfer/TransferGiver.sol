// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {AssetPermitter} from "../../permit/AssetPermitter.sol";

import {AssetRescuer} from "../../rescue/AssetRescuer.sol";

import {Controllable} from "../../control/Controllable.sol";

import {ITransferGiver} from "./interfaces/ITransferGiver.sol";

import {TransferGiveHashLib} from "./libraries/TransferGiveHashLib.sol";

contract TransferGiver is ITransferGiver, PoolAware, AssetPermitter, AssetRescuer, Controllable {
    constructor(
        IFlexPool pool_,
        address controller_
    )
        PoolAware(pool_)
        AssetPermitter(poolAsset)
        Controllable(controller_)
    {}

    function give(uint256 assets_, uint256 takeChain_, address takeReceiver_) public override {
        SafeERC20.safeTransferFrom(poolAsset, msg.sender, address(pool), assets_);
        _emitGiveEvent(assets_, takeChain_, takeReceiver_);
    }

    function giveHold(uint256 assets_, uint256 takeChain_, address takeReceiver_) public override {
        SafeERC20.safeTransfer(poolAsset, address(pool), assets_);
        _emitGiveEvent(assets_, takeChain_, takeReceiver_);
    }

    // ---

    function _canCallRescue(address caller_) internal view override returns (bool) {
        return caller_ == controller;
    }

    function _canRescueAsset(address /* asset_ */) internal pure override returns (bool) {
        return true; // Not designed to hold asset after transaction
    }

    // ---

    function _emitGiveEvent(uint256 assets_, uint256 takeChain_, address takeReceiver_) private {
        bytes32 giveHash = TransferGiveHashLib.calc(assets_, block.number, takeChain_, takeReceiver_);
        emit TransferGive(giveHash);
    }
}
