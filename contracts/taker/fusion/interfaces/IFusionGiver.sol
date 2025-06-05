// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IOrderMixin, TakerTraits, MakerTraits} from "@1inch/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";

import {TimelocksLib} from "@1inch/cross-chain-swap/contracts/libraries/TimelocksLib.sol";
import {IBaseEscrow} from "@1inch/cross-chain-swap/contracts/interfaces/IBaseEscrow.sol";

import {IAssetPermitter} from "../../../permit/interfaces/IAssetPermitter.sol";

import {IFusionBase} from "./IFusionBase.sol";

interface IFusionGiver is IFusionBase, IAssetPermitter {
    error NoPostInteractionCall(MakerTraits makerTraits);
    error PostInteractionListenerNotEscrowFactory(address listener, address escrowFactory);
    error EscrowMakerAssetNotPool(address asset, address poolAsset);
    error InsufficientSafetyDeposit(uint256 deposit, uint256 minDeposit);
    error InvalidTimelocksSequence(TimelocksLib.Stage stage, uint256 time, uint256 minTime);
    error InsufficientPublicWithdrawTime(uint256 time, uint256 minTime);
    error ExcessivePublicWithdrawTime(uint256 time, uint256 maxTime);

    function limitOrderProtocol() external view returns (address);

    function minSafetyDeposit() external view returns (uint256);

    function minPublicWithdrawTime() external view returns (uint256);

    function maxPublicWithdrawTime() external view returns (uint256);

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

    function withdraw(bytes32 secret, IBaseEscrow.Immutables calldata immutables) external;

    function cancel(IBaseEscrow.Immutables calldata immutables) external;

    // `IEscrowSrc` using pre-calculated address

    function withdrawEscrow(address escrow, bytes32 secret, IBaseEscrow.Immutables calldata immutables) external;

    function cancelEscrow(address escrow, IBaseEscrow.Immutables calldata immutables) external;
}
