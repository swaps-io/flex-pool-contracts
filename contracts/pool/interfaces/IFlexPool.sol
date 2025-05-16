// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {IAssetPermitter} from "../../permit/interfaces/IAssetPermitter.sol";

import {IEventVerifier} from "../../verifier/interfaces/IEventVerifier.sol";

interface IFlexPool is IERC4626, IERC20Permit, IAssetPermitter, IEventVerifier {
    event Obligate(bytes32 indexed borrowHash);
    event Borrow(bytes32 indexed borrowHash);

    event EnclavePoolUpdate(uint256 indexed chain, address indexed oldPool, address indexed newPool);
    event ObligorTunerUpdate(address indexed obligor, address indexed oldTuner, address indexed newTuner);
    event FunctionPauseUpdate(uint8 indexed index, bool indexed pause);

    error InvalidBorrowState(bytes32 borrowHash, uint256 state, uint256 expectedState);
    error EquilibriumAffected(int256 assets, int256 minAssets, int256 maxAssets);
    error ReserveAffected(uint256 assets, uint256 minAssets);

    error EventChainMismatch(uint256 chain, uint256 expectedChain);
    error EventEmitterMismatch(address emitter, address expectedEmitter);
    error EventTopicsMismatch(bytes32[] topics, uint256 expectedTopicsLength);
    error EventDataMismatch(bytes data, uint256 expectedDataLength);
    error EventSignatureMismatch(bytes32 eventSignature);

    error SameEnclavePool(uint256 chain, address pool);
    error NoEnclavePool(uint256 chain);
    error SameObligorTuner(address obligor, address tuner);
    error NoObligorTuner(address obligor);
    error SameFunctionPause(uint8 index, bool pause);
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

    function borrowState(bytes32 borrowHash) external view returns (uint256);

    function enclavePool(uint256 chain) external view returns (address);

    function obligorTuner(address obligor) external view returns (address);

    function functionPause(uint8 index) external view returns (bool);

    function convertToEnclaveAssets(uint256 assets) external view returns (uint256);

    function calcBorrowHash(
        uint256 borrowChain,
        uint256 borrowEnclaveAssets,
        address borrowReceiver,
        uint256 obligateChain,
        uint256 obligateNonce
    ) external view returns (bytes32);

    function previewObligate(
        uint256 borrowChain,
        uint256 borrowAssets,
        address obligor,
        bytes calldata tunerData
    ) external view returns (
        uint256 protocolAssets,
        int256 influenceAssets,
        uint256 repayAssets
    );

    function obligate(
        uint256 borrowChain,
        uint256 borrowAssets,
        address borrowReceiver,
        address obligor,
        bytes calldata obligorData_,
        bytes calldata tunerData
    ) external; // Pausable #0

    function borrow(
        uint256 borrowAssets,
        address borrowReceiver,
        uint256 obligateChain,
        uint256 obligateNonce,
        bytes calldata obligateProof
    ) external; // Pausable #1

    // Owner functionality

    function setEnclavePool(uint256 chain, address pool) external;

    function setObligorTuner(address obligor, address tuner) external;

    function setFunctionPause(uint8 index, bool pause) external;
}
