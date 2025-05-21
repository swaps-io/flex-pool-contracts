// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {IAssetPermitter} from "../../permit/interfaces/IAssetPermitter.sol";

import {IEventVerifier} from "../../verifier/interfaces/IEventVerifier.sol";

import {Loan} from "../structs/Loan.sol";
import {TuneParams} from "../structs/TuneParams.sol";
import {TuneResult} from "../structs/TuneResult.sol";
import {GiveParams} from "../structs/GiveParams.sol";
import {TakeParams} from "../structs/TakeParams.sol";
import {ConfirmParams} from "../structs/ConfirmParams.sol";
import {RefuseParams} from "../structs/RefuseParams.sol";
import {CancelParams} from "../structs/CancelParams.sol";

import {LoanState} from "../enums/LoanState.sol";

interface IFlexPool is IERC4626, IERC20Permit, IAssetPermitter, IEventVerifier {
    event Give(bytes32 indexed loanHash);
    event Take(bytes32 indexed loanHash);
    event Confirm(bytes32 indexed loanHash);
    event Refuse(bytes32 indexed loanHash);
    event Cancel(bytes32 indexed loanHash);

    event EnclavePoolUpdate(uint256 indexed chain, address oldPool, address newPool);
    event EnclaveTakeProviderUpdate(
        uint256 indexed takeChain,
        address indexed tuneProvider,
        address indexed giveProvider,
        address oldTakeProvider,
        address newTakeProvider
    );
    event FunctionPause(uint8 indexed index);
    event FunctionUnpause(uint8 indexed index);

    error InsufficientEscrowValue(uint256 value, uint256 minValue);
    error InvalidLoanState(bytes32 loanHash, LoanState state, LoanState expectedState);
    error EquilibriumAffected(int256 assets, int256 minAssets, int256 maxAssets);
    error ReserveAffected(uint256 assets, uint256 minAssets);
    error TakeNoLongerActive(uint256 time, uint256 deadline);
    error TakeStillActive(uint256 time, uint256 deadline);

    error EventChainMismatch(uint256 chain, uint256 expectedChain);
    error EventEmitterMismatch(address emitter, address expectedEmitter);
    error EventTopicsMismatch(bytes32[] topics, uint256 expectedTopicsLength);
    error EventDataMismatch(bytes data, uint256 expectedDataLength);
    error EventSignatureMismatch(bytes32 eventSignature);

    error SameEnclavePool(uint256 chain, address pool);
    error NoEnclavePool(uint256 chain);
    error SameEnclaveTakeProvider(uint256 takeChain, address tuneProvider, address giveProvider, address takeProvider);
    error NoEnclaveTakeProvider(uint256 takeChain, address tuneProvider, address giveProvider);
    error SameFunctionPause(uint8 index);
    error SameFunctionUnpause(uint8 index);
    error FunctionPaused(uint8 index);

    function decimalsOffset() external view returns (uint8);

    function enclaveDecimalsOffset() external view returns (uint8);

    function verifier() external view returns (IEventVerifier);

    function currentAssets() external view returns (uint256);

    function equilibriumAssets() external view returns (int256);

    function availableAssets() external view returns (uint256);

    function reserveAssets() external view returns (uint256);

    function rebalanceReserveAssets() external view returns (uint256);

    function withdrawReserveAssets() external view returns (uint256);

    function loanState(bytes32 loanHash) external view returns (LoanState);

    function loanEscrowValue(bytes32 loanHash) external view returns (uint256);

    function enclavePool(uint256 chain) external view returns (address);

    function enclaveTakeProvider(
        uint256 takeChain,
        address tuneProvider,
        address giveProvider
    ) external view returns (address);

    function functionPause(uint8 index) external view returns (bool);

    function convertToEnclaveAssets(uint256 assets) external view returns (uint256);

    function calcLoanHash(Loan calldata loan) external view returns (bytes32);

    function tune(TuneParams calldata params) external view returns (TuneResult memory);

    function give(GiveParams calldata params) external payable; // Pausable #0

    function take(TakeParams calldata params) external; // Pausable #1

    function confirm(ConfirmParams calldata params) external; // Pausable #2

    function refuse(RefuseParams calldata params) external; // Pausable #3

    function cancel(CancelParams calldata params) external; // Pausable #4

    // Pausable in ERC-4626:
    // - deposit/mint: #5
    // - withdraw/redeem: #6

    // Owner functionality

    function setEnclavePool(uint256 chain, address pool) external;

    function setEnclaveTakeProvider(
        uint256 takeChain,
        address tuneProvider,
        address giveProvider,
        address takeProvider
    ) external;

    function pauseFunction(uint8 index) external;

    function unpauseFunction(uint8 index) external;
}
