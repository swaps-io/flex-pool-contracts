// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IOrderMixin} from "@1inch/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {AssetPermitter} from "../../permit/AssetPermitter.sol";

import {AssetRescuer} from "../../rescue/AssetRescuer.sol";

import {Controllable} from "../../control/Controllable.sol";

import {IFusionGiver, IEscrowSrc} from "./interfaces/IFusionGiver.sol";

contract FusionGiver is IFusionGiver, PoolAware, AssetPermitter, AssetRescuer, Controllable {
    address public immutable override router;

    constructor(
        IFlexPool pool_,
        address controller_,
        address router_
    )
        PoolAware(pool_)
        AssetPermitter(poolAsset)
        Controllable(controller_)
    {
        router = router_;

        // Provide infinite allowance to the router. Any `msg.sender` interactions are limited by logic below, which is
        // designed to be safe - i.e. ensures to not spend extra assets during router interactions other than spending
        // assets provided for the call. This contract also won't verify any contract signature nor allow other ways to
        // obtain permit allowing to take the asset though the router.
        poolAsset.approve(router_, type(uint256).max);
    }

    function fill(uint256 assets_, bytes calldata fillData_) public payable override {
        bytes4 selector = bytes4(fillData_[:4]);
        require(_isFillOrder(selector), NotFillOrderCall(selector));

        // TODO: order validation?
        IOrderMixin.Order calldata order;
        assembly { order := add(fillData_.offset, 4) } // solhint-disable-line no-inline-assembly

        uint256 assetsBefore = poolAsset.balanceOf(address(this));
        uint256 nativeBefore = address(this).balance - msg.value;

        SafeERC20.safeTransferFrom(poolAsset, msg.sender, address(pool), assets_);
        Address.functionCallWithValue(address(router), fillData_, msg.value);

        uint256 assetsAfter = poolAsset.balanceOf(address(this));
        require(assetsAfter >= assetsBefore, GiverAssetsAffected(assetsAfter, assetsBefore));
        if (assetsAfter > assetsBefore) {
            SafeERC20.safeTransfer(poolAsset, msg.sender, assetsAfter - assetsBefore);
        }

        uint256 nativeAfter = address(this).balance;
        if (nativeAfter > nativeBefore) {
            Address.sendValue(payable(msg.sender), nativeAfter - nativeBefore);
        }
    }

    function withdraw(IEscrowSrc escrow_, bytes32 secret_, IEscrowSrc.Immutables calldata immutables_) public override {
        // TODO: shared before-after asset management logic
        uint256 nativeBefore = address(this).balance;

        IEscrowSrc(escrow_).withdrawTo(secret_, address(pool), immutables_);

        uint256 nativeAfter = address(this).balance;
        if (nativeAfter > nativeBefore) {
            Address.sendValue(payable(msg.sender), nativeAfter - nativeBefore);
        }
    }

    // TODO: function for handling result of public withdraw

    // ---

    function _canCallRescue(address caller_) internal view override returns (bool) {
        return caller_ == controller;
    }

    function _canRescueAsset(address asset_) internal view override returns (bool) {
        return asset_ != address(poolAsset);
    }

    // ---

    function _isFillOrder(bytes4 selector_) private pure returns (bool) {
        return (
            selector_ == IOrderMixin.fillOrder.selector ||
            selector_ == IOrderMixin.fillOrderArgs.selector ||
            selector_ == IOrderMixin.fillContractOrder.selector ||
            selector_ == IOrderMixin.fillContractOrderArgs.selector
        );
    }
}
