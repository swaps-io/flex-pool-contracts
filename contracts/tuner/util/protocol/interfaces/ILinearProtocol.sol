// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

interface ILinearProtocol {
    function protocolFixed() external view returns (uint256);

    function protocolPercent() external view returns (uint256);
}
