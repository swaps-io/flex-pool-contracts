// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestSpender {
    function spendToken(IERC20 token_, uint256 assets_, address to_) public {
        token_.transferFrom(msg.sender, to_, assets_);
    }
}

contract TestApprove {
    IERC20 public immutable token;

    constructor(IERC20 token_) {
        token = token_;
    }

    function provideInfiniteApprove(address spender_) public {
        token.approve(spender_, type(uint256).max);
    }

    function testInfiniteApprove(address spender_, uint256 assets_, address to_) public {
        TestSpender(spender_).spendToken(token, assets_, to_);
    }

    function testTemporaryApprove(address spender_, uint256 assets_, address to_) public {
        token.approve(spender_, assets_);
        TestSpender(spender_).spendToken(token, assets_, to_);
        token.approve(spender_, 0);
    }
}
