// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract TestToken is ERC20Permit {
    uint8 private immutable _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_)
        ERC20Permit(name_)
        ERC20(name_, symbol_)
    {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address account_, uint256 assets_) external {
        _mint(account_, assets_);
    }

    function burn(address account_, uint256 assets_) external {
        _burn(account_, assets_);
    }
}
