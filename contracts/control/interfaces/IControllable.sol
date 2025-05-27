// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

interface IControllable {
    error CallerNotController(address caller, address controller);

    function controller() external view returns (address);
}
