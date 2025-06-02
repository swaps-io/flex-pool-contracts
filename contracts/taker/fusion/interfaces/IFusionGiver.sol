// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IOrderMixin, TakerTraits, MakerTraits} from "@1inch/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import {IEscrowSrc} from "@1inch/cross-chain-swap/contracts/interfaces/IEscrowSrc.sol";

import {IPoolAware} from "../../../pool/aware/interfaces/IPoolAware.sol";

import {IAssetPermitter} from "../../../permit/interfaces/IAssetPermitter.sol";

import {IAssetRescuer} from "../../../rescue/interfaces/IAssetRescuer.sol";

import {IControllable} from "../../../control/interfaces/IControllable.sol";

interface IFusionGiver is IPoolAware, IAssetPermitter, IAssetRescuer, IControllable {
    error NoPostInteractionCall(MakerTraits makerTraits);
    error PostInteractionListenerNotEscrowFactory(address listener, address escrowFactory);
    error CallerNotOriginalTaker(address caller, address escrow, address originalTaker);

    function aggregationRouter() external view returns (address);

    function escrowFactory() external view returns (address);

    function originalTaker(address escrow) external view returns (address);

    function transferAssetToPool() external;

    // `IOrderMixin` compatibility

    function fillOrder(
        IOrderMixin.Order calldata order,
        bytes32 r,
        bytes32 vs,
        uint256 amount,
        TakerTraits takerTraits
    ) external payable returns (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash);

    function fillOrderArgs(
        IOrderMixin.Order calldata order,
        bytes32 r,
        bytes32 vs,
        uint256 amount,
        TakerTraits takerTraits,
        bytes calldata args
    ) external payable returns (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash);

    function fillContractOrder(
        IOrderMixin.Order calldata order,
        bytes calldata signature,
        uint256 amount,
        TakerTraits takerTraits
    ) external returns (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash);

    function fillContractOrderArgs(
        IOrderMixin.Order calldata order,
        bytes calldata signature,
        uint256 amount,
        TakerTraits takerTraits,
        bytes calldata args
    ) external returns (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash);

    // `IEscrowSrc` compatibility

    function withdraw(bytes32 secret, IEscrowSrc.Immutables calldata immutables) external;

    function cancel(IEscrowSrc.Immutables calldata immutables) external;

    function rescueFunds(address token, uint256 amount, IEscrowSrc.Immutables calldata immutables) external;

    // `IEscrowSrc` using pre-calculated address

    function withdrawEscrow(address escrow, bytes32 secret, IEscrowSrc.Immutables calldata immutables) external;

    function cancelEscrow(address escrow, IEscrowSrc.Immutables calldata immutables) external;

    function rescueFundsEscrow(
        address escrow,
        address token,
        uint256 amount,
        IEscrowSrc.Immutables calldata immutables
    ) external;
}
