// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library PercentLib {
    uint256 internal constant HUNDRED_PERCENT = 100 ether;

    function calcPercent(uint256 value_, uint256 percent_) internal pure returns (uint256) {
        if (value_ == 0 || percent_ == 0) return 0;
        return Math.mulDiv(value_, percent_, HUNDRED_PERCENT, Math.Rounding.Ceil);
    }
}
