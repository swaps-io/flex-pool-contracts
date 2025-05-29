// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

interface ITaker {
    function take(
        address caller,
        uint256 assets,
        uint256 rewardAssets,
        uint256 giveAssets,
        bytes calldata data
    ) external payable;
}
