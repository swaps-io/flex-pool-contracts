// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IAcrossDepositTaker} from "./interfaces/IAcrossDepositTaker.sol";

import {AcrossBaseTaker, IFlexPool, V3SpokePoolInterface} from "./AcrossBaseTaker.sol";

contract AcrossDepositTaker is IAcrossDepositTaker, AcrossBaseTaker {
    uint32 private constant FILL_TIME_TOTAL = 10 minutes;
    uint32 private constant FILL_TIME_EXCLUSIVE = 1 minutes;

    constructor(
        IFlexPool pool_,
        address controller_,
        V3SpokePoolInterface spokePool_,
        uint256 giveChain_,
        address givePool_,
        address givePoolAsset_,
        int256 giveDecimalsShift_
    )
        AcrossBaseTaker(
            pool_,
            controller_,
            spokePool_,
            giveChain_,
            givePool_,
            givePoolAsset_,
            giveDecimalsShift_
        )
    {}

    function takeToDeposit(
        uint256 assets_,
        uint256 inputAmount_,
        uint256 outputAmount_,
        bytes32 exclusiveRelayer_
    ) public override {
        uint256 baseAssets = _trackTokenBefore(poolAsset);
        uint256 minGiveAssets = pool.take(assets_);
        uint256 takeAssets = _trackTokenBefore(poolAsset) - baseAssets;
        _verifyTakeAssets(takeAssets, inputAmount_);
        _verifyGiveAssets(outputAmount_, minGiveAssets);

        _deposit(inputAmount_, outputAmount_, exclusiveRelayer_);
        _trackTokenAfter(poolAsset, baseAssets);
    }

    // ---

    function _deposit(uint256 inputAmount_, uint256 outputAmount_, bytes32 exclusiveRelayer_) private {
        uint32 currentTime = uint32(block.timestamp);
        spokePool.deposit(
            _address32(address(pool)),         // bytes32 depositor
            _address32(givePool),              // bytes32 recipient
            _address32(address(poolAsset)),    // bytes32 inputToken
            _address32(givePoolAsset),         // bytes32 outputToken
            inputAmount_,                      // uint256 inputAmount
            outputAmount_,                     // uint256 outputAmount
            giveChain,                         // uint256 destinationChainId
            exclusiveRelayer_,                 // bytes32 exclusiveRelayer
            currentTime,                       // uint32  quoteTimestamp
            currentTime + FILL_TIME_TOTAL,     // uint32  fillDeadline
            currentTime + FILL_TIME_EXCLUSIVE, // uint32  exclusivityParameter
            ""                                 // bytes   message
        );
    }
}
