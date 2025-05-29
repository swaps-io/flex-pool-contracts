// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ERC4626, IERC4626, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Permit, IERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {AssetPermitter} from "../permit/AssetPermitter.sol";

import {AssetRescuer} from "../rescue/AssetRescuer.sol";

import {Controllable} from "../control/Controllable.sol";

import {Guard} from "../guard/Guard.sol";

import {ITuner} from "../tuner/interfaces/ITuner.sol";

import {ITaker} from "../taker/interfaces/ITaker.sol";

import {IFlexPool} from "./interfaces/IFlexPool.sol";

contract FlexPool is IFlexPool, ERC4626, ERC20Permit, AssetPermitter, AssetRescuer, Controllable, Guard, Multicall {
    uint8 public immutable override decimalsOffset;

    uint256 public override rebalanceAssets;
    mapping(address taker => address) public override tuner;

    uint256 private _totalAssets;

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        uint8 decimalsOffset_,
        address controller_
    )
        ERC4626(asset_)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        AssetPermitter(asset_)
        Controllable(controller_)
    {
        decimalsOffset = decimalsOffset_;
    }

    // Read

    function decimals() public view override(ERC4626, ERC20, IERC20Metadata) returns (uint8) {
        return ERC4626.decimals();
    }

    function nonces(address owner_) public view override(ERC20Permit, IERC20Permit) returns (uint256) {
        return ERC20Permit.nonces(owner_);
    }

    function totalAssets() public view override(ERC4626, IERC4626) returns (uint256) {
        return _totalAssets;
    }

    function currentAssets() public view override returns (uint256) {
        return ERC4626.totalAssets();
    }

    function equilibriumAssets() public view override returns (int256) {
        return int256(availableAssets()) - int256(_totalAssets);
    }

    function availableAssets() public view override returns (uint256) {
        return currentAssets() - rebalanceAssets; // Non-negativeness ensured by `_verifyAssets`
    }

    function clampAssetsToAvailable(uint256 assets_) public view override returns (uint256) {
        return Math.min(assets_, availableAssets());
    }

    function clampSharesToAvailable(uint256 shares_) public view override returns (uint256) {
        return Math.min(shares_, previewWithdraw(availableAssets()));
    }

    // Write

    function take(
        uint256 assets_,
        address taker_,
        bytes calldata takerData_,
        bytes calldata tunerData_
    ) public payable override guard {
        address tuner_ = tuner[taker_];
        require(tuner_ != address(0), NoTuner(taker_));

        (uint256 protocolAssets, int256 rebalanceAssets_) = ITuner(tuner_).tune(assets_, tunerData_);

        uint256 giveAssets = assets_;
        if (protocolAssets != 0) {
            giveAssets += protocolAssets;
            _totalAssets += protocolAssets;
        }

        uint256 rewardAssets = 0;
        uint256 takerAssets = assets_;
        if (rebalanceAssets_ > 0) {
            giveAssets += uint256(rebalanceAssets_);
            rebalanceAssets += uint256(rebalanceAssets_);
        } else {
            rewardAssets = uint256(-rebalanceAssets_);
            takerAssets += rewardAssets;
            rebalanceAssets -= rewardAssets;
        }

        SafeERC20.safeTransfer(IERC20(asset()), taker_, takerAssets);
        _verifyAssets();

        ITaker(taker_).take{value: msg.value}(msg.sender, assets_, rewardAssets, giveAssets, takerData_);
        emit Take(taker_, assets_, protocolAssets, rebalanceAssets_);
    }

    function withdrawAvailable(uint256 assets_, address receiver_, address owner_) public override returns (uint256) {
        return withdraw(clampAssetsToAvailable(assets_), receiver_, owner_);
    }

    function redeemAvailable(uint256 shares_, address receiver_, address owner_) public override returns (uint256) {
        return redeem(clampSharesToAvailable(shares_), receiver_, owner_);
    }

    function donateRebalance(uint256 assets_) public override {
        SafeERC20.safeTransferFrom(IERC20(asset()), msg.sender, address(this), assets_);
        rebalanceAssets += assets_;
        emit RebalanceDonation(msg.sender, assets_);
    }

    function setTuner(address taker_, address tuner_) public override onlyController {
        address oldTuner = tuner[taker_];
        require(tuner_ != oldTuner, SameTuner(taker_, tuner_));
        tuner[taker_] = tuner_;
        emit TunerUpdate(taker_, oldTuner, tuner_);
    }

    // ---

    function _decimalsOffset() internal view override returns (uint8) {
        return decimalsOffset;
    }

    function _deposit(
        address caller_,
        address receiver_,
        uint256 assets_,
        uint256 shares_
    ) internal override {
        ERC4626._deposit(caller_, receiver_, assets_, shares_);
        _totalAssets += assets_;
    }

    function _withdraw(
        address caller_,
        address receiver_,
        address owner_,
        uint256 assets_,
        uint256 shares_
    ) internal override {
        _totalAssets -= assets_;
        ERC4626._withdraw(caller_, receiver_, owner_, assets_, shares_);
        _verifyAssets();
    }

    function _canCallRescue(address caller_) internal view override returns (bool) {
        return caller_ == controller;
    }

    function _canRescueAsset(address asset_) internal view override returns (bool) {
        return asset_ != asset();
    }

    // ---

    function _verifyAssets() private view {
        require(currentAssets() >= rebalanceAssets, RebalanceAffected(currentAssets(), rebalanceAssets));
    }
}
