// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

library AssetLib {
    function isNative(address asset_) internal pure returns (bool) {
        return asset_ == address(0);
    }
}
