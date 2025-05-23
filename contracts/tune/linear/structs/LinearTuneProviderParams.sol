// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

struct LinearTuneProviderParams {
    address pool;
    uint256 maxTakeDeadlineTime;
    uint256 maxTakeDeadlineTimePercent;
    uint256 maxExclusiveCancelTime;
    uint256 maxExclusiveCancelTimePercent;
    uint256 escrowValueConstant;
    uint256 escrowValuePercent;
    uint256 escrowAssetsConvertPercent;
    uint256 protocolAssetsConstant;
    uint256 protocolAssetsPercent;
    uint256 rebalanceAssetsConstant;
    uint256 rebalanceAssetsPercent;
}
