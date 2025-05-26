// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library PercentLib {
    uint256 internal constant HUNDRED_PERCENT = 100 ether;

    function applyPercent(uint256 value_, uint256 percent_) internal pure returns (uint256) {
        return Math.mulDiv(value_, percent_, HUNDRED_PERCENT, Math.Rounding.Ceil);
    }
}
