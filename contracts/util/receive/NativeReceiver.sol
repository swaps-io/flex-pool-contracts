// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

abstract contract NativeReceiver {
    receive() external payable {}
}
