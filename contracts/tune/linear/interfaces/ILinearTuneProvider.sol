// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IPoolAware} from "../../../aware/interfaces/IPoolAware.sol";

import {ITuneProvider} from "../../interfaces/ITuneProvider.sol";

interface ILinearTuneProvider is ITuneProvider, IPoolAware {
    error TakeDeadlineInactive(uint256 time, uint256 deadline);
    error MaxTakeDeadlineTimeExceeded(uint256 time, uint256 maxTime);
    error MaxExclusiveCancelTimeExceeded(uint256 time, uint256 maxTime);

    function maxTakeDeadlineTime() external view returns (uint256);

    function maxTakeDeadlineTimePercent() external view returns (uint256);

    function maxExclusiveCancelTime() external view returns (uint256);

    function maxExclusiveCancelTimePercent() external view returns (uint256);

    function escrowValueConstant() external view returns (uint256);

    function escrowValuePercent() external view returns (uint256);

    function escrowAssetsConvertPercent() external view returns (uint256);

    function protocolAssetsConstant() external view returns (uint256);

    function protocolAssetsPercent() external view returns (uint256);

    function rebalanceAssetsConstant() external view returns (int256);

    function rebalanceAssetsPercent() external view returns (uint256);
}
