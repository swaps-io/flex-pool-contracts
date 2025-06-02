// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IBaseEscrow} from "@1inch/cross-chain-swap/contracts/interfaces/IBaseEscrow.sol";

import {IPoolAware} from "../../../pool/aware/interfaces/IPoolAware.sol";

import {IAssetRescuer} from "../../../rescue/interfaces/IAssetRescuer.sol";

import {IControllable} from "../../../control/interfaces/IControllable.sol";

interface IFusionBase is IPoolAware, IAssetRescuer, IControllable {
    error CallerNotOriginalTaker(address caller, address escrow, address originalTaker);

    function escrowFactory() external view returns (address);

    function originalTaker(address escrow) external view returns (address);

    function predictEscrow(IBaseEscrow.Immutables calldata immutables) external view returns (address);

    function transferAssetToPool() external;

    // `IBaseEscrow` compatibility

    function rescueFunds(address token, uint256 amount, IBaseEscrow.Immutables calldata immutables) external;

    // `IBaseEscrow` using pre-calculated address

    function rescueFundsEscrow(
        address escrow,
        address token,
        uint256 amount,
        IBaseEscrow.Immutables calldata immutables
    ) external;
}
