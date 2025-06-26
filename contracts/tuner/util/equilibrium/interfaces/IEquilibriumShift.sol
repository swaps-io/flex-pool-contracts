// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

interface IEquilibriumShift {
    function equilibriumShift() external view returns (int256);

    function setEquilibriumShift(int256 assets) external;
}
