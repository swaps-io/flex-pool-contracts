// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

interface IObligor {
    function obligate(uint256 repayAssets, bytes calldata data) external returns (uint256 obligateNonce);
}
