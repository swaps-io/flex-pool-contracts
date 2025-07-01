// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {PercentLib} from "../../../util/libraries/PercentLib.sol";

import {ILinearRebalance} from "./interfaces/ILinearRebalance.sol";

abstract contract LinearRebalanceFossil is ILinearRebalance {
    uint256 public immutable override rebalanceFixed;
    uint256 public immutable override rebalancePercent;

    constructor(
        uint256 rebalanceFixed_,
        uint256 rebalancePercent_
    ) {
        rebalanceFixed = rebalanceFixed_;
        rebalancePercent = rebalancePercent_;
    }

    function _applyLinearRebalance(uint256 assets_) internal view returns (uint256) {
        return rebalanceFixed + PercentLib.applyPercent(assets_, rebalancePercent);
    }
}
