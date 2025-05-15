// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PoolObligor, IFlexPool} from "../pool/PoolObligor.sol";

import {ITransferObligor} from "./interfaces/ITransferObligor.sol";

contract TransferObligor is ITransferObligor, PoolObligor {
    constructor(IFlexPool pool_)
        PoolObligor(pool_)
    {}

    function _obligate(
        uint256 repayAssets_,
        bytes calldata data_
    ) internal override returns (uint256 obligateNonce) {
        SafeERC20.safeTransfer(poolAsset, address(pool), repayAssets_);
        obligateNonce = uint256(bytes32(data_[0:32]));
    }
}
