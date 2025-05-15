// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ERC4626, IERC4626, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Permit, IERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

import {AssetPermitter} from "../permit/AssetPermitter.sol";

import {IFlexPool, IObligor, ITuner, IEventVerifier} from "./interfaces/IFlexPool.sol";

import {BorrowHashLib} from "./libraries/BorrowHashLib.sol";

contract FlexPool is IFlexPool, ERC4626, ERC20Permit, AssetPermitter, Ownable2Step, Multicall {
    bytes32 private constant OBLIGATE_EVENT_SIGNATURE = keccak256("Obligate(bytes32)");
    bytes32 private constant BORROW_EVENT_SIGNATURE = keccak256("Borrow(bytes32)");

    uint256 private constant BORROW_STATE_NONE = 0;
    uint256 private constant BORROW_STATE_OBLIGATED = 1;
    uint256 private constant BORROW_STATE_BORROWED = 2;

    uint8 public immutable override decimalsOffset;
    ITuner public immutable override tuner;
    IEventVerifier public immutable override verifier;

    int256 public override equilibriumAssets;
    uint256 public override reserveAssets;
    uint256 public override withdrawReserveAssets;
    mapping(bytes32 borrowHash => uint256) public override borrowState;
    mapping(uint256 chain => address) public override enclavePool;
    mapping(address obligor => bool) public override obligorEnable;

    uint256 private _functionPauseBits;

    modifier pausable(uint8 index_) {
        require(!functionPause(index_), FunctionPaused(index_));
        _;
    }

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        uint8 decimalsOffset_,
        ITuner tuner_,
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
        tuner = tuner_;
        verifier = verifier_;
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

    function functionPause(uint8 index_) public view override returns (bool) {
        return 1 << index_ & _functionPauseBits != 0;
    }

    function calcBorrowHash(
        uint256 borrowChain_,
        uint256 borrowAssets_,
        address borrowReceiver_,
        uint256 obligateChain_,
        uint256 obligateNonce_
    ) external pure override returns (bytes32) {
        return BorrowHashLib.calc(borrowChain_, borrowAssets_, borrowReceiver_, obligateChain_, obligateNonce_);
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
        IObligor obligor_,
        bytes calldata obligorData_
    ) external override pausable(0) {
        (/* uint256 protocolAssets */,
            uint256 rebalanceAssets,
            uint256 repayAssets
        ) = previewTune(borrowChain_, borrowAssets_, borrowReceiver_, tunerData_);

        require(obligorEnable[address(obligor_)], ObligorDisabled(address(obligor_)));
        uint256 obligateNonce = obligor_.obligate(repayAssets, obligorData_);

        bytes32 borrowHash = BorrowHashLib.calc(
            borrowChain_,
            borrowAssets_,
            borrowReceiver_,
            block.chainid,
            obligateNonce
        );
        _verifyBorrowState(borrowHash, BORROW_STATE_NONE);
        borrowState[borrowHash] = BORROW_STATE_OBLIGATED;

        _shiftEquilibriumAssets(int256(repayAssets), false, false);
        _gainReserveAssets(rebalanceAssets, false);

        emit Obligate(borrowHash);
    }

    function borrow(
        uint256 borrowAssets_,
        address borrowReceiver_,
        uint256 obligateChain_,
        uint256 obligateNonce_,
        bytes calldata obligateProof_
    ) external override pausable(1) {
        bytes32 borrowHash = BorrowHashLib.calc(
            block.chainid,
            borrowAssets_,
            borrowReceiver_,
            obligateChain_,
            obligateNonce_
        );

        if (obligateChain_ == block.chainid) {
            _verifyBorrowState(borrowHash, BORROW_STATE_OBLIGATED);
        } else {
            _verifyBorrowState(borrowHash, BORROW_STATE_NONE);
            _verifyObligateEvent(obligateChain_, borrowHash, obligateProof_);
        }
        borrowState[borrowHash] = BORROW_STATE_BORROWED;

        _shiftEquilibriumAssets(-int256(borrowAssets_), false, false);
        _sendAssets(borrowAssets_, borrowReceiver_);

        emit Borrow(borrowHash);
    }

    function verifyEvent(
        uint256 chain_,
        address emitter_,
        bytes32[] calldata topics_,
        bytes calldata data_,
        bytes calldata /* proof_ */
    ) external view override {
        require(chain_ == block.chainid, EventChainMismatch(chain_, block.chainid));
        require(emitter_ == address(this), EventEmitterMismatch(emitter_, address(this)));
        require(topics_.length != 2, EventTopicsMismatch(topics_, 2));
        require(data_.length == 0, EventDataMismatch(data_, 0));

        bytes32 eventSignature = topics_[0];
        if (eventSignature == OBLIGATE_EVENT_SIGNATURE) {
            _verifyBorrowState(topics_[1], BORROW_STATE_OBLIGATED);
        } else if (eventSignature == BORROW_EVENT_SIGNATURE) {
            _verifyBorrowState(topics_[1], BORROW_STATE_BORROWED);
        } else {
            revert EventSignatureMismatch(eventSignature);
        }
    }

    // Owner functionality

    function setEnclavePool(uint256 chain_, address pool_) external override onlyOwner {
        address oldPool = enclavePool[chain_];
        require(pool_ != oldPool, SameEnclavePool(chain_, pool_));
        enclavePool[chain_] = pool_;
        emit EnclavePoolUpdate(chain_, oldPool, pool_);
    }

    function setObligorEnable(address obligor_, bool enable_) external override onlyOwner {
        require(enable_ != obligorEnable[obligor_], SameObligorEnable(obligor_, enable_));
        obligorEnable[obligor_] = enable_;
        emit ObligorEnableUpdate(obligor_, enable_);
    }

    function setFunctionPause(uint8 index_, bool pause_) external override onlyOwner {
        uint256 mask = 1 << index_;
        uint256 bits = _functionPauseBits;
        require(pause_ != (bits & mask != 0), SameFunctionPause(index_, pause_));
        _functionPauseBits = pause_ ? bits | mask : bits & ~mask;
        emit FunctionPauseUpdate(index_, pause_);
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
    ) internal override pausable(2) {
        ERC4626._deposit(caller_, receiver_, assets_, shares_);
    }

    function _withdraw(
        address caller_,
        address receiver_,
        address owner_,
        uint256 assets_,
        uint256 shares_
    ) internal override pausable(3) {
        ERC4626._withdraw(caller_, receiver_, owner_, assets_, shares_);
    }

    // ---

    function _verifyBorrowState(bytes32 borrowHash_, uint256 expectedState_) private view {
        uint256 state = borrowState[borrowHash_];
        require(state == expectedState_, InvalidBorrowState(borrowHash_, state, expectedState_));
    }

    function _verifyReserveAssets() private view {
        require(currentAssets() >= reserveAssets, ReserveAffected(currentAssets(), reserveAssets));
    }

    function _verifyObligateEvent(uint256 chain_, bytes32 borrowHash_, bytes calldata proof_) private {
        address emitter = enclavePool[chain_];
        require(emitter != address(0), NoEnclavePool(chain_));
        bytes32[] memory topics = new bytes32[](2);
        topics[0] = OBLIGATE_EVENT_SIGNATURE;
        topics[1] = borrowHash_;
        verifier.verifyEvent(chain_, emitter, topics, "", proof_);
    }

    function _shiftEquilibriumAssets(int256 assets_, bool positive_, bool negative_) private {
        int256 newAssets = equilibriumAssets + assets_;
        if (positive_) {
            require(newAssets >= 0, EquilibriumAffected(newAssets, 0, type(int256).max));
        }
        if (negative_) {
            require(newAssets <= 0, EquilibriumAffected(newAssets, type(int256).min, 0));
        }
        equilibriumAssets = newAssets;
    }

    function _gainReserveAssets(uint256 assets_, bool withdraw_) private {
        reserveAssets += assets_;
        if (withdraw_) {
            withdrawReserveAssets += assets_;
        }
    }

    function _sendAssets(uint256 assets_, address receiver_) private {
        SafeERC20.safeTransfer(IERC20(asset()), receiver_, assets_);
        _verifyReserveAssets();
    }
}
