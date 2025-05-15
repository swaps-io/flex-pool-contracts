// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IFlexPool} from "../../../pool/interfaces/IFlexPool.sol";

import {IObligor} from "../../interfaces/IObligor.sol";

interface IPoolObligor is IObligor {
    error CallerNotPool(address caller, address pool);

    function pool() external view returns (IFlexPool);

    function poolAsset() external view returns (IERC20);
}
