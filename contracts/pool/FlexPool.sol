// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {ERC4626, ERC20, IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Permit, IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

import {AssetPermitter} from "../permit/AssetPermitter.sol";

import {IFlexPool} from "./interfaces/IFlexPool.sol";

contract FlexPool is IFlexPool, ERC4626, ERC20Permit, AssetPermitter, Multicall {
    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_
    )
        ERC4626(asset_)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        AssetPermitter(asset_)
    {}

    function decimals() public view virtual override(ERC4626, ERC20, IERC20Metadata) returns (uint8) {
        return ERC4626.decimals();
    }

    function nonces(address owner_) public view virtual override(ERC20Permit, IERC20Permit) returns (uint256) {
        return ERC20Permit.nonces(owner_);
    }
}
