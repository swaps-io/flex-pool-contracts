// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ERC4626, IERC4626, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Permit, IERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

import {AssetPermitter} from "../permit/AssetPermitter.sol";

import {IFlexPool, IObligor, ITuner, IEventVerifier, IPoolRouter} from "./interfaces/IFlexPool.sol";

import {BorrowHashLib} from "./libraries/BorrowHashLib.sol";

contract FlexPool is IFlexPool, ERC4626, ERC20Permit, AssetPermitter, Multicall {
    bytes32 private constant OBLIGATE_EVENT_SIGNATURE = keccak256("Obligate(bytes32)");

    IObligor public immutable override obligor;
    ITuner public immutable override tuner;
    IEventVerifier public immutable override verifier;
    IPoolRouter public immutable override pools;

    int256 public override equilibriumAssets;
    uint256 public override reserveAssets;
    uint256 public override withdrawReserveAssets;
    mapping(bytes32 borrowHash => uint256) public override borrowState;

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        IObligor obligor_,
        ITuner tuner_,
        IEventVerifier verifier_,
        IPoolRouter pools_
    )
        ERC4626(asset_)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        AssetPermitter(asset_)
    {
        obligor = obligor_;
        tuner = tuner_;
        verifier = verifier_;
        pools = pools_;
    }

    function decimals() public view virtual override(ERC4626, ERC20, IERC20Metadata) returns (uint8) {
        return ERC4626.decimals();
    }

    function nonces(address owner_) public view virtual override(ERC20Permit, IERC20Permit) returns (uint256) {
        return ERC20Permit.nonces(owner_);
    }

    function totalAssets() public view virtual override(ERC4626, IERC4626) returns (uint256) {
        return uint256(int256(availableAssets()) - equilibriumAssets);
    }

    function currentAssets() public view override returns (uint256) {
        return ERC4626.totalAssets();
    }

    function availableAssets() public view override returns (uint256) {
        return currentAssets() - reserveAssets;
    }

    function rebalanceReserveAssets() public view override returns (uint256) {
        return reserveAssets - withdrawReserveAssets;
    }

    function previewTune(
        uint256 borrowChain_,
        uint256 borrowAssets_,
        address borrowReceiver_,
        bytes calldata tunerData_
    ) public override view returns (
        uint256 protocolAssets,
        uint256 rebalanceAssets,
        uint256 repayAssets
    ) {
        (protocolAssets, rebalanceAssets) = tuner.tune(borrowChain_, borrowAssets_, borrowReceiver_, tunerData_);
        repayAssets = borrowAssets_ + protocolAssets + rebalanceAssets;
    }

    function obligate(
        uint256 borrowChain_,
        uint256 borrowAssets_,
        address borrowReceiver_,
        bytes calldata tunerData_,
        bytes calldata obligorData_
    ) external override {
        (/* uint256 protocolAssets */,
            uint256 rebalanceAssets,
            uint256 repayAssets
        ) = previewTune(borrowChain_, borrowAssets_, borrowReceiver_, tunerData_);

        bytes32 obligateHash = obligor.obligate(repayAssets, obligorData_);

        bytes32 borrowHash = BorrowHashLib.calc(
            borrowChain_,
            borrowAssets_,
            borrowReceiver_,
            block.chainid,
            obligateHash
        );
        uint256 state = borrowState[borrowHash];
        require(state == 0, InvalidBorrowState(borrowHash, state));
        borrowState[borrowHash] = 1;

        _shiftEquilibriumAssets(int256(repayAssets), 0);
        _gainReserveAssets(rebalanceAssets, 0);

        emit Obligate(borrowHash);
    }

    function borrow(
        uint256 borrowAssets_,
        address borrowReceiver_,
        uint256 obligateChain_,
        bytes32 obligateHash_,
        bytes calldata obligateProof_
    ) external override {
        bytes32 borrowHash = BorrowHashLib.calc(
            block.chainid,
            borrowAssets_,
            borrowReceiver_,
            obligateChain_,
            obligateHash_
        );
        uint256 state = borrowState[borrowHash];

        if (obligateChain_ == block.chainid) {
            require(state == 1, InvalidBorrowState(borrowHash, state));
        } else {
            require(state == 0, InvalidBorrowState(borrowHash, state));

            address obligateEmitter = pools.pool(obligateChain_);
            bytes32[] memory obligateTopics = new bytes32[](2);
            obligateTopics[0] = OBLIGATE_EVENT_SIGNATURE;
            obligateTopics[1] = borrowHash;
            verifier.verifyEvent(obligateChain_, obligateEmitter, obligateTopics, "", obligateProof_);
        }
        borrowState[borrowHash] = 2;

        _shiftEquilibriumAssets(-int256(borrowAssets_), 0);
        _sendAssets(borrowAssets_, borrowReceiver_);

        emit Borrow(borrowHash);
    }

    function _shiftEquilibriumAssets(int256 assets_, uint256 flags_) internal {
        int256 newAssets = equilibriumAssets + assets_;
        if (flags_ & 1 != 0) {
            require(newAssets >= 0, EquilibriumAffected(newAssets, 0, type(int256).max));
        }
        if (flags_ & 2 != 0) {
            require(newAssets <= 0, EquilibriumAffected(newAssets, type(int256).min, 0));
        }
        equilibriumAssets = newAssets;
    }

    function _gainReserveAssets(uint256 assets_, uint256 flags_) internal {
        reserveAssets += assets_;
        if (flags_ & 1 != 0) {
            withdrawReserveAssets += assets_;
        }
    }

    function _verifyReserveAssets() private view {
        require(currentAssets() >= reserveAssets, ReserveAffected(currentAssets(), reserveAssets));
    }

    function _sendAssets(uint256 assets_, address receiver_) internal {
        SafeERC20.safeTransfer(IERC20(asset()), receiver_, assets_);
        _verifyReserveAssets();
    }
}
