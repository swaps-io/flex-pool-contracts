// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

interface IPoolRouter {
    function pool(uint256 chain) external view returns (address);
}
