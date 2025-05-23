// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

library EnclaveDataLib {
    bytes32 internal constant EMPTY_DATA = 0;

    // Read

    function readPool(bytes32 data_) internal pure returns (address) {
        return address(uint160(uint256(data_)));
    }

    function readDecimals(bytes32 data_) internal pure returns (uint8) {
        return uint8(uint256(data_) >> 160);
    }

    // Make

    function makeData(address pool_, uint8 decimals_) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(pool_)) | uint256(decimals_) << 160);
    }
}
