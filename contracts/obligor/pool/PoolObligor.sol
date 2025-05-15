// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IPoolObligor, IFlexPool, IERC20} from "./interfaces/IPoolObligor.sol";

abstract contract PoolObligor is IPoolObligor {
    IFlexPool public immutable override pool;
    IERC20 public immutable override poolAsset;

    modifier onlyPool {
        require(msg.sender == address(pool), CallerNotPool(msg.sender, address(pool)));
        _;
    }

    constructor(IFlexPool pool_) {
        pool = pool_;
        poolAsset = IERC20(pool_.asset());
    }

    function obligate(
        uint256 repayAssets_,
        bytes calldata data_
    ) external override onlyPool returns (bytes32 obligateHash) {
        return _obligate(repayAssets_, data_);
    }

    function _obligate(
        uint256 repayAssets,
        bytes calldata data
    ) internal virtual returns (bytes32 obligateHash);
}
