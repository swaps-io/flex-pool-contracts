// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ERC4626, IERC4626, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Permit, IERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Multicall, Address} from "@openzeppelin/contracts/utils/Multicall.sol";

import {AssetPermitter} from "../permit/AssetPermitter.sol";

import {ITuneProvider, TuneProviderParams, TuneProviderResult} from "../tune/interfaces/ITuneProvider.sol";

import {IGiveProvider} from "../give/interfaces/IGiveProvider.sol";

import {ITakeProvider} from "../take/interfaces/ITakeProvider.sol";

import { IFlexPool, IEventVerifier, Loan, LoanTakeState, LoanGiveState, TuneParams, TuneResult, GiveParams, TakeParams,
    ConfirmParams, RefuseParams, CancelParams } from "./interfaces/IFlexPool.sol";

import {LoanHashLib} from "./libraries/LoanHashLib.sol";
import {LoanStateDataLib} from "./libraries/LoanStateDataLib.sol";
import {FunctionPauseDataLib} from "./libraries/FunctionPauseDataLib.sol";
import {DeadlineLib} from "./libraries/DeadlineLib.sol";
import {TakeDeadlineLib} from "./libraries/TakeDeadlineLib.sol";

contract FlexPool is IFlexPool, ERC4626, ERC20Permit, AssetPermitter, Ownable2Step, Multicall {
    bytes32 private constant GIVE_EVENT_SIGNATURE = keccak256("Give(bytes32)");
    bytes32 private constant TAKE_EVENT_SIGNATURE = keccak256("Take(bytes32)");
    bytes32 private constant CONFIRM_EVENT_SIGNATURE = keccak256("Confirm(bytes32)");
    bytes32 private constant REFUSE_EVENT_SIGNATURE = keccak256("Refuse(bytes32)");
    bytes32 private constant CANCEL_EVENT_SIGNATURE = keccak256("Cancel(bytes32)");

    uint8 public immutable override decimalsOffset;
    uint8 public immutable override enclaveDecimalsOffset;
    IEventVerifier public immutable override verifier;

    int256 public override equilibriumAssets;
    uint256 public override reserveAssets;
    uint256 public override withdrawReserveAssets;
    mapping(uint256 chain => address) public override enclavePool;
    mapping(uint256 takeChain => mapping(address tuneProvider => mapping(address giveProvider => address)))
        public override enclaveTakeProvider;

    mapping(bytes32 loanHash => uint256) private _loanStateData;
    uint256 private _functionPauseData;

    modifier pausable(uint8 index_) {
        require(!functionPause(index_), FunctionPaused(index_));
        _;
    }

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        uint8 decimalsOffset_,
        uint8 enclaveDecimalsOffset_,
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
        enclaveDecimalsOffset = enclaveDecimalsOffset_;
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

    function loanGiveState(bytes32 loanHash_) external view override returns (LoanGiveState) {
        return LoanStateDataLib.readGiveState(_loanStateData[loanHash_]);
    }

    function loanTakeState(bytes32 loanHash_) external view override returns (LoanTakeState) {
        return LoanStateDataLib.readTakeState(_loanStateData[loanHash_]);
    }

    function loanEscrowValue(bytes32 loanHash_) external view override returns (uint256) {
        return LoanStateDataLib.readEscrowValue(_loanStateData[loanHash_]);
    }

    function functionPause(uint8 index_) public view override returns (bool) {
        return FunctionPauseDataLib.readPause(_functionPauseData, index_);
    }

    function convertToEnclaveAssets(uint256 assets_) public view override returns (uint256) {
        return assets_ * 10 ** enclaveDecimalsOffset;
    }

    function calcLoanHash(Loan calldata loan_) external pure override returns (bytes32) {
        return LoanHashLib.calc(loan_);
    }

    function tune(TuneParams memory params_) public view override returns (TuneResult memory result) {
        TuneProviderResult memory providerResult = ITuneProvider(params_.tuneProvider).tune(TuneProviderParams({
            giveProvider: params_.giveProvider,
            giveExecutor: params_.giveExecutor,
            takeChain: params_.takeChain,
            takeProvider: params_.takeProvider,
            takeAssets: params_.takeAssets,
            takeDeadline: params_.takeDeadline,
            extraData: params_.tuneExtraData
        }));

        result.escrowValue = providerResult.escrowValue;
        result.protocolAssets = providerResult.protocolAssets;
        result.rebalanceAssets = providerResult.rebalanceAssets;

        result.giveAssets = params_.takeAssets + result.protocolAssets;
        if (result.rebalanceAssets > 0) {
            result.giveAssets += uint256(result.rebalanceAssets);
        }
    }

    function give(GiveParams calldata params_) external payable override pausable(0) {
        address takeProvider = enclaveTakeProvider[params_.takeChain][params_.tuneProvider][params_.giveProvider];
        require(
            takeProvider != address(0),
            NoEnclaveTakeProvider(params_.takeChain, params_.tuneProvider, params_.giveProvider)
        );

        TuneResult memory tuneResult = tune(TuneParams({
            tuneProvider: params_.tuneProvider,
            giveProvider: params_.giveProvider,
            giveExecutor: _msgSender(),
            takeChain: params_.takeChain,
            takeProvider: takeProvider,
            takeAssets: params_.takeAssets,
            takeDeadline: params_.takeDeadline,
            tuneExtraData: params_.tuneExtraData
        }));
        require(msg.value >= tuneResult.escrowValue, InsufficientEscrowValue(msg.value, tuneResult.escrowValue));

        bytes32 loanHash = LoanHashLib.calc(Loan({
            giveChain: block.chainid,
            giveProvider: params_.giveProvider,
            giveExecutor: params_.giveExecutor,
            takeChain: params_.takeChain,
            takeProvider: takeProvider,
            takeEnclaveAssets: convertToEnclaveAssets(params_.takeAssets),
            takeDeadline: params_.takeDeadline,
            providerDataHash: keccak256(params_.providerData)
        }));

        uint256 stateData = _loanStateData[loanHash];
        _verifyGiveState(stateData, LoanGiveState.None, loanHash);
        stateData = LoanStateDataLib.writeEscrowValue(stateData, msg.value);
        _loanStateData[loanHash] = LoanStateDataLib.writeGiveState(stateData, LoanGiveState.Given);

        IGiveProvider(params_.giveProvider).give(tuneResult.giveAssets, params_.providerData);

        // TODO: update pool assets

        emit Give(loanHash);
    }

    function take(TakeParams calldata params_) external override pausable(1) {
        uint256 takeDeadline = TakeDeadlineLib.readTakeDeadline(params_.takeDeadline);
        require(DeadlineLib.active(takeDeadline), TakeNoLongerActive(DeadlineLib.time(), takeDeadline));

        bytes32 loanHash = LoanHashLib.calc(Loan({
            giveChain: params_.giveChain,
            giveProvider: params_.giveProvider,
            giveExecutor: params_.giveExecutor,
            takeChain: block.chainid,
            takeProvider: params_.takeProvider,
            takeEnclaveAssets: convertToEnclaveAssets(params_.takeAssets),
            takeDeadline: params_.takeDeadline,
            providerDataHash: keccak256(params_.providerData)
        }));

        uint256 stateData = _loanStateData[loanHash];
        _verifyTakeState(stateData, LoanTakeState.None, loanHash);
        if (params_.giveChain == block.chainid) {
            _verifyGiveState(stateData, LoanGiveState.Given, loanHash);
        } else {
            _verifyPoolEvent(params_.giveChain, GIVE_EVENT_SIGNATURE, loanHash, params_.giveProof);
        }
        _loanStateData[loanHash] = LoanStateDataLib.writeTakeState(stateData, LoanTakeState.Taken);

        // TODO: update pool assets

        ITakeProvider(params_.takeProvider).take(params_.takeAssets, params_.providerData);

        emit Take(loanHash);
    }

    function confirm(ConfirmParams calldata params_) external override pausable(2) {
        bytes32 loanHash = LoanHashLib.calc(Loan({
            giveChain: block.chainid,
            giveProvider: params_.giveProvider,
            giveExecutor: params_.giveExecutor,
            takeChain: params_.takeChain,
            takeProvider: params_.takeProvider,
            takeEnclaveAssets: convertToEnclaveAssets(params_.takeAssets),
            takeDeadline: params_.takeDeadline,
            providerDataHash: params_.providerDataHash
        }));

        uint256 stateData = _loanStateData[loanHash];
        _verifyGiveState(stateData, LoanGiveState.Given, loanHash);
        if (params_.takeChain == block.chainid) {
            _verifyTakeState(stateData, LoanTakeState.Taken, loanHash);
        } else {
            _verifyPoolEvent(params_.takeChain, TAKE_EVENT_SIGNATURE, loanHash, params_.takeProof);
        }
        _loanStateData[loanHash] = LoanStateDataLib.writeGiveState(stateData, LoanGiveState.Confirmed);

        _sendValue(LoanStateDataLib.readEscrowValue(stateData), params_.giveExecutor);

        emit Confirm(loanHash);
    }

    function refuse(RefuseParams calldata params_) external override pausable(3) {
        uint256 takeDeadline = TakeDeadlineLib.readTakeDeadline(params_.takeDeadline);
        require(!DeadlineLib.active(takeDeadline), TakeStillActive(DeadlineLib.time(), takeDeadline));

        bytes32 loanHash = LoanHashLib.calc(Loan({
            giveChain: params_.giveChain,
            giveProvider: params_.giveProvider,
            giveExecutor: params_.giveExecutor,
            takeChain: block.chainid,
            takeProvider: params_.takeProvider,
            takeEnclaveAssets: convertToEnclaveAssets(params_.takeAssets),
            takeDeadline: params_.takeDeadline,
            providerDataHash: params_.providerDataHash
        }));

        uint256 stateData = _loanStateData[loanHash];
        _verifyTakeState(stateData, LoanTakeState.None, loanHash);
        _loanStateData[loanHash] = LoanStateDataLib.writeTakeState(stateData, LoanTakeState.Refused);

        emit Refuse(loanHash);
    }

    function cancel(CancelParams calldata params_) external override pausable(4) {
        uint256 exclusiveDeadline = TakeDeadlineLib.readExclusiveCancelDeadline(params_.takeDeadline);
        if (DeadlineLib.active(exclusiveDeadline)) {
            require(
                _msgSender() == params_.giveExecutor,
                ExclusiveCancelStillActive(_msgSender(), params_.giveExecutor, DeadlineLib.time(), exclusiveDeadline)
            );
        }

        bytes32 loanHash = LoanHashLib.calc(Loan({
            giveChain: block.chainid,
            giveProvider: params_.giveProvider,
            giveExecutor: params_.giveExecutor,
            takeChain: params_.takeChain,
            takeProvider: params_.takeProvider,
            takeEnclaveAssets: convertToEnclaveAssets(params_.takeAssets),
            takeDeadline: params_.takeDeadline,
            providerDataHash: params_.providerDataHash
        }));

        uint256 stateData = _loanStateData[loanHash];
        _verifyGiveState(stateData, LoanGiveState.Given, loanHash);
        if (params_.takeChain == block.chainid) {
            _verifyTakeState(stateData, LoanTakeState.Refused, loanHash);
        } else {
            _verifyPoolEvent(params_.takeChain, REFUSE_EVENT_SIGNATURE, loanHash, params_.refuseProof);
        }
        _loanStateData[loanHash] = LoanStateDataLib.writeGiveState(stateData, LoanGiveState.Cancelled);

        // TODO: update pool assets
        _sendValue(LoanStateDataLib.readEscrowValue(stateData), _msgSender());

        emit Cancel(loanHash);
    }

    function verifyEvent(
        uint256 chain_,
        address emitter_,
        bytes32[] calldata topics_,
        bytes calldata data_,
        bytes calldata proof_
    ) external view override {
        require(chain_ == block.chainid, EventChainMismatch(chain_, block.chainid));
        require(emitter_ == address(this), EventEmitterMismatch(emitter_, address(this)));
        require(topics_.length != 2, EventTopicsMismatch(topics_, 2));
        require(data_.length == 0, EventDataMismatch(data_, 0));

        bytes32 eventSignature = topics_[0];
        bytes32 loanHash = topics_[1];
        uint256 stateData = _loanStateData[loanHash];

        if (eventSignature == GIVE_EVENT_SIGNATURE) {
            uint256 giveVariant = proof_.length > 0 ? uint256(bytes32(proof_[0:32])) : 0;
            if (giveVariant == uint256(LoanGiveState.Confirmed)) {
                _verifyGiveState(stateData, LoanGiveState.Confirmed, loanHash);
            } else if (giveVariant == uint256(LoanGiveState.Cancelled)) {
                _verifyGiveState(stateData, LoanGiveState.Cancelled, loanHash);
            } else {
                _verifyGiveState(stateData, LoanGiveState.Given, loanHash);
            }
        } else if (eventSignature == TAKE_EVENT_SIGNATURE) {
            _verifyTakeState(stateData, LoanTakeState.Taken, loanHash);
        } else if (eventSignature == CONFIRM_EVENT_SIGNATURE) {
            _verifyGiveState(stateData, LoanGiveState.Confirmed, loanHash);
        } else if (eventSignature == REFUSE_EVENT_SIGNATURE) {
            _verifyTakeState(stateData, LoanTakeState.Refused, loanHash);
        } else if (eventSignature == CANCEL_EVENT_SIGNATURE) {
            _verifyGiveState(stateData, LoanGiveState.Cancelled, loanHash);
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

    function setEnclaveTakeProvider(
        uint256 takeChain_,
        address tuneProvider_,
        address giveProvider_,
        address takeProvider_
    ) external override onlyOwner {
        address oldTakeProvider = enclaveTakeProvider[takeChain_][tuneProvider_][giveProvider_];
        require(
            takeProvider_ != oldTakeProvider,
            SameEnclaveTakeProvider(takeChain_, tuneProvider_, giveProvider_, takeProvider_)
        );
        enclaveTakeProvider[takeChain_][tuneProvider_][giveProvider_] = takeProvider_;
        emit EnclaveTakeProviderUpdate(takeChain_, tuneProvider_, giveProvider_, oldTakeProvider, takeProvider_);
    }

    function pauseFunction(uint8 index_) external override onlyOwner {
        uint256 pauseData = _functionPauseData;
        require(!FunctionPauseDataLib.readPause(pauseData, index_), SameFunctionPause(index_));
        _functionPauseData = FunctionPauseDataLib.writePause(pauseData, index_);
        emit FunctionPause(index_);
    }

    function unpauseFunction(uint8 index_) external override onlyOwner {
        uint256 pauseData = _functionPauseData;
        require(FunctionPauseDataLib.readPause(pauseData, index_), SameFunctionUnpause(index_));
        _functionPauseData = FunctionPauseDataLib.writeUnpause(pauseData, index_);
        emit FunctionUnpause(index_);
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
    ) internal override pausable(5) {
        ERC4626._deposit(caller_, receiver_, assets_, shares_);
    }

    function _withdraw(
        address caller_,
        address receiver_,
        address owner_,
        uint256 assets_,
        uint256 shares_
    ) internal override pausable(6) {
        ERC4626._withdraw(caller_, receiver_, owner_, assets_, shares_);
    }

    // ---

    function _verifyGiveState(uint256 stateData_, LoanGiveState expectedState_, bytes32 loanHash_) private pure {
        LoanGiveState state = LoanStateDataLib.readGiveState(stateData_);
        require(state == expectedState_, InvalidLoanGiveState(loanHash_, state, expectedState_));
    }

    function _verifyTakeState(uint256 stateData_, LoanTakeState expectedState_, bytes32 loanHash_) private pure {
        LoanTakeState state = LoanStateDataLib.readTakeState(stateData_);
        require(state == expectedState_, InvalidLoanTakeState(loanHash_, state, expectedState_));
    }

    function _verifyReserveAssets() private view {
        require(currentAssets() >= reserveAssets, ReserveAffected(currentAssets(), reserveAssets));
    }

    function _verifyPoolEvent(uint256 chain_, bytes32 topic0_, bytes32 topic1_, bytes calldata proof_) private {
        address emitter = enclavePool[chain_];
        require(emitter != address(0), NoEnclavePool(chain_));
        bytes32[] memory topics = new bytes32[](2);
        topics[0] = topic0_;
        topics[1] = topic1_;
        verifier.verifyEvent(chain_, emitter, topics, "", proof_);
    }

    function _sendAssets(uint256 assets_, address receiver_) private {
        SafeERC20.safeTransfer(IERC20(asset()), receiver_, assets_);
        _verifyReserveAssets();
    }

    function _sendValue(uint256 value_, address receiver_) private {
        Address.sendValue(payable(receiver_), value_);
    }
}
