// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

abstract contract Guard {
    // keccak256(abi.encode(uint256(keccak256("swaps-io/flex-pool/Guard.GUARD_SLOT")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant GUARD_SLOT = 0xecb7e621bf68138e439325d8e8e423515dcad92058ef329075cab3e08d938000;

    error GuardReentrant();

    constructor() {
        _initGuard();
    }

    modifier guard {
        require(!_getGuard(), GuardReentrant());
        _setGuard(true);
        _;
        _setGuard(false);
    }

    function _getGuard() internal view virtual returns (bool) {
        return StorageSlot.getUint256Slot(GUARD_SLOT).value == 2;
    }

    function _setGuard(bool value_) internal virtual {
        StorageSlot.getUint256Slot(GUARD_SLOT).value = value_ ? 2 : 1;
    }

    function _initGuard() internal virtual {
        StorageSlot.getUint256Slot(GUARD_SLOT).value = 1;
    }
}
