// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {AssetLib} from "../libraries/AssetLib.sol";

import {TrackNative} from "./TrackNative.sol";
import {TrackToken, IERC20} from "./TrackToken.sol";

abstract contract TrackAsset is TrackNative, TrackToken {
    modifier trackAsset(address asset_) {
        uint256 amountBefore = AssetLib.isNative(asset_) ? _trackNativeBefore() : _trackTokenBefore(IERC20(asset_));
        _;
        AssetLib.isNative(asset_) ? _trackNativeAfter(amountBefore) : _trackTokenAfter(IERC20(asset_), amountBefore);
    }
}
