// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PoolAware, IFlexPool} from "../../aware/PoolAware.sol";

import {ITransferGiveProvider} from "./interfaces/ITransferGiveProvider.sol";

contract TransferGiveProvider is ITransferGiveProvider, PoolAware {
    constructor(IFlexPool pool_)
        PoolAware(pool_)
    {}

    function give(uint256 assets_, bytes calldata /* data_ */) external override onlyPool {
        SafeERC20.safeTransfer(poolAsset, address(pool), assets_);
    }
}
