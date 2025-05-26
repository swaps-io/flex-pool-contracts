// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

interface ITaker {
    function identify(bytes calldata data) external view returns (bytes32 id);

    function take(
        address caller,
        uint256 assets,
        uint256 rewardAssets,
        uint256 giveAssets,
        bytes32 id,
        bytes calldata data
    ) external payable;
}
