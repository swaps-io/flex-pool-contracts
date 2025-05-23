// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ERC4626, IERC4626, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Permit, IERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {AssetPermitter} from "../../permit/AssetPermitter.sol";

import {ITuner} from "../tuner/interfaces/ITuner.sol";

import {ITaker} from "../taker/interfaces/ITaker.sol";

import {IFlexPoolNext, IEventVerifier} from "./interfaces/IFlexPoolNext.sol";

import {EnclaveDataLib} from "./libraries/EnclaveDataLib.sol";

contract FlexPoolNext is IFlexPoolNext, ERC4626, ERC20Permit, AssetPermitter, Ownable2Step, Multicall {
    uint8 public immutable override decimalsOffset;
    IEventVerifier public immutable override verifier;

    uint256 public override reserveAssets;
    uint256 public override withdrawReserveAssets;
    mapping(address taker => address) public override tuner;
    mapping(bytes32 id => bool) public override taken;

    uint256 private _totalAssets;
    mapping(uint256 chain => bytes32) private _enclaveData;

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        uint8 decimalsOffset_,
        IEventVerifier verifier_,
        address initialOwner_
    )
        ERC4626(asset_)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        AssetPermitter(asset_)
        Ownable(initialOwner_)
    {
        decimalsOffset = decimalsOffset_;
        verifier = verifier_;
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

    function enclave(uint256 chain_) public view override returns (address pool, uint8 decimals_) {
        bytes32 data = _enclaveData[chain_];
        pool = EnclaveDataLib.readPool(data);
        decimals_ = EnclaveDataLib.readDecimals(data);
    }

    function enclavePool(uint256 chain_) public view override returns (address) {
        return EnclaveDataLib.readPool(_enclaveData[chain_]);
    }

    function enclaveDecimals(uint256 chain_) public view override returns (uint8) {
        return EnclaveDataLib.readDecimals(_enclaveData[chain_]);
    }

    // Write

    function take(
        uint256 assets_,
        address taker_,
        bytes calldata takerData_,
        bytes calldata tunerData_
    ) public payable override {
        bytes32 id = ITaker(taker_).identify(assets_, takerData_);
        require(!taken[id], AlreadyTaken(id));
        taken[id] = true;

        address tuner_ = tuner[taker_];
        require(tuner_ != address(0), NoTuner(taker_));

        (uint256 protocolAssets, uint256 rebalanceAssets) = ITuner(tuner_).tune(assets_, tunerData_);
        uint256 giveAssets = assets_ + protocolAssets + rebalanceAssets;

        _totalAssets += protocolAssets;
        reserveAssets += rebalanceAssets;

        uint256 rewardAssets = _calcRebalanceReward(assets_);
        reserveAssets -= rewardAssets;

        _sendAssets(assets_ + rewardAssets, taker_);
        ITaker(taker_).take{value: msg.value}(assets_, rewardAssets, giveAssets, id, takerData_);
        emit Take(id);
    }

    // Write - owner

    function expandEnclave(uint256 chain_, address pool_, uint8 decimals_) public override onlyOwner {
        require(pool_ != address(0), ZeroEnclavePool());
        require(_enclaveData[chain_] == EnclaveDataLib.EMPTY_DATA, AlreadyEnclave(chain_));
        _enclaveData[chain_] = EnclaveDataLib.makeData(pool_, decimals_);
        emit EnclaveExpand(chain_, pool_, decimals_);
    }

    function shrinkEnclave(uint256 chain_) public override onlyOwner {
        require(_enclaveData[chain_] != EnclaveDataLib.EMPTY_DATA, NoEnclave(chain_));
        _enclaveData[chain_] = EnclaveDataLib.EMPTY_DATA;
        emit EnclaveShrink(chain_);
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
