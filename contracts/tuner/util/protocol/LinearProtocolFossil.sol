// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {PercentLib} from "../../../util/libraries/PercentLib.sol";

import {ILinearProtocol} from "./interfaces/ILinearProtocol.sol";

abstract contract LinearProtocolFossil is ILinearProtocol {
    uint256 public immutable override protocolFixed;
    uint256 public immutable override protocolPercent;

    constructor(
        uint256 protocolFixed_,
        uint256 protocolPercent_
    ) {
        protocolFixed = protocolFixed_;
        protocolPercent = protocolPercent_;
    }

    function _applyLinearProtocol(uint256 assets_) internal view returns (uint256) {
        return protocolFixed + PercentLib.applyPercent(assets_, protocolPercent);
    }
}
