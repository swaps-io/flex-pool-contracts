// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ERC4626, IERC4626, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Permit, IERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {AssetPermitter} from "../permit/AssetPermitter.sol";

import {ITuner} from "../tuner/interfaces/ITuner.sol";

import {ITaker} from "../taker/interfaces/ITaker.sol";

import {IFlexPool} from "./interfaces/IFlexPool.sol";

contract FlexPool is IFlexPool, ERC4626, ERC20Permit, AssetPermitter, Ownable2Step, Multicall {
    bytes32 private constant TAKE_EVENT_SIGNATURE = keccak256("Take(bytes32)");

    uint8 public immutable override decimalsOffset;

    uint256 public override reserveAssets;
    uint256 public override withdrawReserveAssets;
    mapping(address taker => address) public override tuner;
    mapping(bytes32 id => bool) public override taken;

    uint256 private _totalAssets;

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        uint8 decimalsOffset_,
        address initialOwner_
    )
        ERC4626(asset_)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        AssetPermitter(asset_)
        Ownable(initialOwner_)
    {
        decimalsOffset = decimalsOffset_;
    }

    // Read

    function decimals() public view virtual override(ERC4626, ERC20, IERC20Metadata) returns (uint8) {
        return ERC4626.decimals();
    }

    function nonces(address owner_) public view virtual override(ERC20Permit, IERC20Permit) returns (uint256) {
        return ERC20Permit.nonces(owner_);
    }

    function totalAssets() public view override(ERC4626, IERC4626) returns (uint256) {
        return _totalAssets;
    }

    function currentAssets() public view override returns (uint256) {
        return ERC4626.totalAssets();
    }

    function equilibriumAssets() public view override returns (int256) {
        return int256(currentAssets()) - int256(_totalAssets);
    }

    function availableAssets() public view override returns (uint256) {
        return currentAssets() - reserveAssets;
    }

    function rebalanceReserveAssets() public view override returns (uint256) {
        return reserveAssets - withdrawReserveAssets; // TODO: withdraw queue impl
    }

    // Write

    function take(
        uint256 assets_,
        address taker_,
        bytes calldata takerData_,
        bytes calldata tunerData_
    ) public payable override {
        address tuner_ = tuner[taker_];
        require(tuner_ != address(0), NoTuner(taker_));

        bytes32 id = ITaker(taker_).identify(takerData_);
        require(!taken[id], AlreadyTaken(id));
        taken[id] = true;

        (uint256 protocolAssets, uint256 rebalanceAssets) = ITuner(tuner_).tune(assets_, tunerData_);
        uint256 giveAssets = assets_ + protocolAssets + rebalanceAssets;

        _totalAssets += protocolAssets;
        reserveAssets += rebalanceAssets;

        uint256 rewardAssets = _calcRebalanceReward(assets_);
        reserveAssets -= rewardAssets;

        _sendAssets(assets_ + rewardAssets, taker_);
        ITaker(taker_).take{value: msg.value}(msg.sender, assets_, rewardAssets, giveAssets, id, takerData_);
        emit Take(id);
    }

    function verifyEvent(
        uint256 chain_,
        address emitter_,
        bytes32[] calldata topics_,
        bytes calldata data_,
        bytes calldata /* proof */
    ) public override view {
        require(
            chain_ == block.chainid &&
            emitter_ == address(this) &&
            data_.length == 0 &&
            topics_.length == 2 &&
            topics_[0] == TAKE_EVENT_SIGNATURE &&
            taken[topics_[1]],
            InvalidEvent(chain_, emitter_, topics_, data_)
        );
    }

    // Write - owner

    function setTuner(address taker_, address tuner_) public override onlyOwner {
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
    }

    // ---

    function _verifyReserveAssets() private view {
        require(currentAssets() >= reserveAssets, ReserveAffected(currentAssets(), reserveAssets));
    }

    function _calcRebalanceReward(uint256 assets_) private view returns (uint256 reward) {
        int256 equilibrium = equilibriumAssets();
        if (equilibrium > 0) {
            uint256 rebalance = Math.min(uint256(equilibrium), assets_);
            reward = Math.mulDiv(rebalanceReserveAssets(), rebalance, uint256(equilibrium));
        }
    }

    function _sendAssets(uint256 assets_, address receiver_) private {
        SafeERC20.safeTransfer(IERC20(asset()), receiver_, assets_);
        _verifyReserveAssets();
    }
}
