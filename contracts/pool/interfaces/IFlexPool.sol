// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {IAssetPermitter} from "../../permit/interfaces/IAssetPermitter.sol";

import {IAssetRescuer} from "../../rescue/interfaces/IAssetRescuer.sol";

import {IControllable} from "../../control/Controllable.sol";

interface IFlexPool is IERC4626, IERC20Permit, IAssetPermitter, IAssetRescuer, IControllable {
    // Event

    event Take(address indexed taker, uint256 assets, uint256 protocolAssets, int256 rebalanceAssets);
    event TunerUpdate(address indexed taker, address indexed oldTuner, address indexed newTuner);

    // Error

    error NoTuner(address taker);
    error RebalanceAffected(uint256 assets, uint256 minAssets);
    error SameTuner(address taker, address tuner);
    error InvalidEvent(uint256 chain, address emitter, bytes32[] topics, bytes data);

    // Read

    function decimalsOffset() external view returns (uint8);

    function currentAssets() external view returns (uint256);

    function equilibriumAssets() external view returns (int256);

    function availableAssets() external view returns (uint256);

    function rebalanceAssets() external view returns (uint256);

    function tuner(address taker) external view returns (address);

    function clampAssetsToAvailable(uint256 assets) external view returns (uint256);

    function clampSharesToAvailable(uint256 shares) external view returns (uint256);

    // Write

    function take(uint256 assets) external returns (uint256 takeAssets, uint256 minGiveAssets);

    function withdrawAvailable(uint256 assets, address receiver, address owner) external returns (uint256);

    function redeemAvailable(uint256 shares, address receiver, address owner) external returns (uint256);

    function setTuner(address taker, address tuner) external; // Only controller
}
