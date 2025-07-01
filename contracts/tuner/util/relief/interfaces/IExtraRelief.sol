// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

interface IExtraRelief {
    function extraReliefAssets() external view returns (uint256);

    function setExtraReliefAssets(uint256 assets) external;
}
