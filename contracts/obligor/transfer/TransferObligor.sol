// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

import {AssetPermitter} from "../../permit/AssetPermitter.sol";

import {PoolObligor, IFlexPool} from "../pool/PoolObligor.sol";

import {ITransferObligor} from "./interfaces/ITransferObligor.sol";

contract TransferObligor is ITransferObligor, PoolObligor, AssetPermitter, Multicall {
    constructor(IFlexPool pool_)
        PoolObligor(pool_)
        AssetPermitter(poolAsset)
    {}

    function _obligate(
        uint256 repayAssets_,
        bytes calldata data_
    ) internal override returns (bytes32 obligateHash) {
        SafeERC20.safeTransfer(poolAsset, address(pool), repayAssets_);
        obligateHash = bytes32(data_[0:32]);
    }
}
