// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {IAssetPermitter} from "../../permit/interfaces/IAssetPermitter.sol";

import {IObligor} from "../../obligor/interfaces/IObligor.sol";

import {ITuner} from "../../tuner/interfaces/ITuner.sol";

import {IEventVerifier} from "../../verifier/interfaces/IEventVerifier.sol";

interface IFlexPool is IERC4626, IERC20Permit, IAssetPermitter {
    event Obligate(bytes32 indexed borrowHash);
    event Borrow(bytes32 indexed borrowHash);

    event EnclavePoolUpdate(uint256 indexed chain, address indexed oldPool, address indexed newPool);
    event ObligorEnableUpdate(address indexed obligor, bool indexed enable);
    event FunctionPauseUpdate(uint8 indexed index, bool indexed pause);

    error InvalidBorrowState(bytes32 borrowHash, uint256 state, uint256 expectedState);
    error EquilibriumAffected(int256 assets, int256 minAssets, int256 maxAssets);
    error ReserveAffected(uint256 assets, uint256 minAssets);

    error SameEnclavePool(uint256 chain, address pool);
    error NoEnclavePool(uint256 chain);
    error SameObligorEnable(address obligor, bool enable);
    error ObligorDisabled(address obligor);
    error SameFunctionPause(uint8 index, bool pause);
    error FunctionPaused(uint8 index);

    function tuner() external view returns (ITuner);

    function verifier() external view returns (IEventVerifier);

    function currentAssets() external view returns (uint256);

    function equilibriumAssets() external view returns (int256);

    function availableAssets() external view returns (uint256);

    function reserveAssets() external view returns (uint256);

    function rebalanceReserveAssets() external view returns (uint256);

    function withdrawReserveAssets() external view returns (uint256);

    function borrowState(bytes32 borrowHash) external view returns (uint256);

    function enclavePool(uint256 chain) external view returns (address);

    function obligorEnable(address obligor) external view returns (bool);

    function functionPause(uint8 index) external view returns (bool);

    function calcBorrowHash(
        uint256 borrowChain,
        uint256 borrowAssets,
        address borrowReceiver,
        uint256 obligateChain,
        bytes32 obligateHash
    ) external view returns (bytes32);

    function previewTune(
        uint256 borrowChain,
        uint256 borrowAssets,
        address borrowReceiver,
        bytes calldata tunerData
    ) external view returns (
        uint256 protocolAssets,
        uint256 rebalanceAssets,
        uint256 repayAssets
    );

    function obligate(
        uint256 borrowChain,
        uint256 borrowAssets,
        address borrowReceiver,
        bytes calldata tunerData,
        IObligor obligor,
        bytes calldata obligorData
    ) external; // Pausable #0

    function borrow(
        uint256 borrowAssets,
        address borrowReceiver,
        uint256 obligateChain,
        bytes32 obligateHash,
        bytes calldata obligateProof
    ) external; // Pausable #1

    // Owner functionality

    function setEnclavePool(uint256 chain, address pool) external;

    function setObligorEnable(address obligor, bool enable) external;

    function setFunctionPause(uint8 index, bool pause) external;
}
