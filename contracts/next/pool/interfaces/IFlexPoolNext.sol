// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {IAssetPermitter} from "../../../permit/interfaces/IAssetPermitter.sol";

import {IEventVerifier} from "../../../verifier/interfaces/IEventVerifier.sol";

interface IFlexPoolNext is IERC4626, IERC20Permit, IAssetPermitter, IEventVerifier {
    // Event

    event Take(bytes32 indexed id);
    event TunerUpdate(address indexed taker, address indexed oldTuner, address indexed newTuner);

    // Error

    error NoTuner(address taker);
    error AlreadyTaken(bytes32 id);
    error ReserveAffected(uint256 assets, uint256 minAssets);
    error SameTuner(address taker, address tuner);
    error InvalidEvent(uint256 chain, address emitter, bytes32[] topics, bytes data);

    // Read

    function decimalsOffset() external view returns (uint8);

    function currentAssets() external view returns (uint256);

    function equilibriumAssets() external view returns (int256);

    function availableAssets() external view returns (uint256);

    function reserveAssets() external view returns (uint256);

    function rebalanceReserveAssets() external view returns (uint256);

    function withdrawReserveAssets() external view returns (uint256);

    function tuner(address taker) external view returns (address);

    function taken(bytes32 id) external view returns (bool);

    // Write

    function take(
        uint256 assets,
        address taker,
        bytes calldata takerData,
        bytes calldata tunerData
    ) external payable;

    // Write - owner

    function setTuner(address taker, address tuner) external;

    // TODO: consider pausable

    // TODO: consider non-asset rescue
}
