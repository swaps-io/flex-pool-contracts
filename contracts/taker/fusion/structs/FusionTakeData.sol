// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IEscrowFactory, IBaseEscrow} from "@1inch/cross-chain-swap/contracts/interfaces/IEscrowFactory.sol";

struct FusionTakeData {
    IBaseEscrow.Immutables srcImmutables;
    IEscrowFactory.DstImmutablesComplement dstImmutablesComplement;
    bytes srcEscrowCreatedProof;
}
