// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {IAssetPermitter} from "../../permit/interfaces/IAssetPermitter.sol";

import {IObligor} from "../../obligor/interfaces/IObligor.sol";

import {ITuner} from "../../tuner/interfaces/ITuner.sol";

import {IEventVerifier} from "../../verifier/interfaces/IEventVerifier.sol";

import {IPoolRouter} from "../router/interfaces/IPoolRouter.sol";

interface IFlexPool is IERC4626, IERC20Permit, IAssetPermitter {
    event Obligate(bytes32 indexed borrowHash);
    event Borrow(bytes32 indexed borrowHash);

    error InvalidBorrowState(bytes32 borrowHash, uint256 borrowState);

    function obligor() external view returns (IObligor);

    function tuner() external view returns (ITuner);

    function verifier() external view returns (IEventVerifier);

    function pools() external view returns (IPoolRouter);

    function currentAssets() external view returns (uint256);

    function equilibriumAssets() external view returns (int256);

    function availableAssets() external view returns (uint256);

    function reserveAssets() external view returns (uint256);

    function borrowState(bytes32 borrowHash) external view returns (uint256);

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
        bytes calldata obligorData
    ) external;

    function borrow(
        uint256 borrowAssets,
        address borrowReceiver,
        uint256 obligateChain,
        bytes32 obligateHash,
        bytes calldata obligateProof
    ) external;
}
