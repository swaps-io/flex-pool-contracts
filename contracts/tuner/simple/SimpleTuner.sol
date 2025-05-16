// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

import {IObligor} from "../../obligor/interfaces/IObligor.sol";

import {PoolTuner, IFlexPool} from "../pool/PoolTuner.sol";

import {PercentLib} from "../libraries/PercentLib.sol";

import {ISimpleTuner} from "./interfaces/ISimpleTuner.sol";

contract SimpleTuner is ISimpleTuner, PoolTuner, Ownable2Step, Multicall {
    uint256 public override protocolPercent;

    constructor(
        IFlexPool pool_,
        uint256 initialProtocolPercent_,
        address initialOwner_
    )
        PoolTuner(pool_)
        Ownable(initialOwner_)
    {
        protocolPercent = initialProtocolPercent_;
    }

    function tune(
        uint256 /* borrowChain_ */,
        uint256 borrowAssets_,
        IObligor /* obligor_ */,
        bytes calldata /* data_ */
    ) external view override returns (
        uint256 protocolAssets,
        int256 influenceAssets
    ) {
        protocolAssets = PercentLib.calcPercent(borrowAssets_, protocolPercent);
        influenceAssets = 0; // TODO
    }

    // Owner functionality

    function setProtocolPercent(uint256 percent_) external override onlyOwner {
        require(protocolPercent != percent_, SameProtocolPercent(percent_));
        protocolPercent = percent_;
        emit ProtocolPercentUpdate(protocolPercent, percent_);
    }
}
