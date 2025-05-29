// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {TransientSlot} from "@openzeppelin/contracts/utils/TransientSlot.sol";

import {FlexPool, IERC20} from "./FlexPool.sol";

contract FlexPoolCancun is FlexPool {
    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        uint8 decimalsOffset_,
        address controller_
    )
        FlexPool(asset_, name_, symbol_, decimalsOffset_, controller_)
    {}

    // ---

    function _getGuard() internal view override returns (bool) {
        return TransientSlot.tload(TransientSlot.asBoolean(GUARD_SLOT));
    }

    function _setGuard(bool value_) internal override {
        TransientSlot.tstore(TransientSlot.asBoolean(GUARD_SLOT), value_);
    }

    function _initGuard() internal override {} // Transient storage doesn't need init
}
