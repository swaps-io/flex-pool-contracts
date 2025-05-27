// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IAssetRescuer} from "./interfaces/IAssetRescuer.sol";

abstract contract AssetRescuer is IAssetRescuer {
    address private constant NATIVE_ASSET = address(0);

    function rescue(address asset_, uint256 amount_, address to_) public override {
        require(_canCallRescue(msg.sender), RescueCallerNotAllowed(msg.sender));
        require(_canRescueAsset(asset_), RescueAssetNotAllowed(asset_));

        if (asset_ == NATIVE_ASSET) {
            Address.sendValue(payable(to_), amount_);
        } else {
            SafeERC20.safeTransfer(IERC20(asset_), to_, amount_);
        }
    }

    function _canCallRescue(address caller) internal view virtual returns (bool);

    function _canRescueAsset(address asset) internal view virtual returns (bool);
}
