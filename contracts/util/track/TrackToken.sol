// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract TrackToken {
    error TrackTokenAffected(address token, uint256 after_, uint256 before);

    modifier trackToken(IERC20 token_) {
        uint256 amountBefore = _trackTokenBefore(token_);
        _;
        _trackTokenAfter(token_, amountBefore);
    }

    function _trackTokenBefore(IERC20 token_) internal view returns (uint256 amountBefore) {
        return token_.balanceOf(address(this));
    }

    function _trackTokenAfter(IERC20 token_, uint256 amountBefore_) internal {
        _trackTokenAfter(token_, amountBefore_, msg.sender);
    }

    function _trackTokenAfter(IERC20 token_, uint256 amountBefore_, address receiver_) internal {
        uint256 amountAfter = token_.balanceOf(address(this));
        require(amountAfter >= amountBefore_, TrackTokenAffected(address(token_), amountAfter, amountBefore_));
        if (amountAfter > amountBefore_) {
            SafeERC20.safeTransfer(token_, receiver_, amountAfter - amountBefore_);
        }
    }
}
