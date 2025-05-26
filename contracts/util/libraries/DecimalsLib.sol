// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

library DecimalsLib {
    function increase(uint256 value_, uint256 decimals_) internal pure returns (uint256) {
        return value_ * 10 ** decimals_;
    }

    function common(
        uint256 leftValue_,   //  5 |  6 | 18
        uint256 rightValue_,  //  9 |  0 | 18
        int256 decimalsShift_ // +4 | -6 |  0
    ) internal pure returns (
        uint256 leftCommon,
        uint256 rightCommon
    ) {
        if (decimalsShift_ > 0) {
            leftValue_ = increase(leftValue_, uint256(decimalsShift_));
        } else if (decimalsShift_ < 0) {
            rightValue_ = increase(rightValue_, uint256(-decimalsShift_));
        }
        return (leftValue_, rightValue_);
    }
}
