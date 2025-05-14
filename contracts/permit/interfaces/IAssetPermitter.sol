// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IAssetPermitter {
    function permitAsset() external view returns (IERC20);

    function usePermit(address from, uint256 amount, uint256 deadline, bytes32 r, bytes32 vs) external;

    function useDaiPermit(address from, bool allowed, uint256 deadline, bytes32 r, bytes32 vs) external;

    function useUniswapPermit(address from, uint256 amount, uint256 deadline, bytes calldata signature) external;

    function useSafePermit(address from, uint256 amount, bytes calldata signature) external;
}
