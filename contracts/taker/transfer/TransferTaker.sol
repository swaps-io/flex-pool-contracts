// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {DecimalsLib} from "../../util/libraries/DecimalsLib.sol";

import {ITransferTaker, IERC20, IEventVerifier} from "./interfaces/ITransferTaker.sol";

import {TransferTakeData} from "./structs/TransferTakeData.sol";

import {TransferGiveHashLib} from "./libraries/TransferGiveHashLib.sol";

contract TransferTaker is ITransferTaker {
    bytes32 private constant TRANSFER_GIVE_EVENT_SIGNATURE = keccak256("TransferGive(bytes32)");

    IERC20 public immutable override asset;
    IEventVerifier public immutable override verifier;
    uint256 public immutable override giveChain;
    address public immutable override giveTransferGiver;
    int256 public immutable override giveDecimalsShift;

    constructor(
        IERC20 asset_,
        IEventVerifier verifier_,
        uint256 giveChain_,
        address giveTransferGiver_,
        int256 giveDecimalsShift_
    ) {
        asset = asset_;
        verifier = verifier_;
        giveChain = giveChain_;
        giveTransferGiver = giveTransferGiver_;
        giveDecimalsShift = giveDecimalsShift_;
    }

    function identify(bytes calldata data_) public view override returns (bytes32 id) {
        TransferTakeData calldata takeData = _decodeData(data_);
        return TransferGiveHashLib.calc(takeData.giveAssets, takeData.giveBlock, block.chainid, takeData.takeReceiver);
    }

    function take(
        address /* caller_ */,
        uint256 assets_,
        uint256 rewardAssets_,
        uint256 giveAssets_,
        bytes32 id_,
        bytes calldata data_
    ) public payable override {
        TransferTakeData calldata takeData = _decodeData(data_);
        _verifyGiveAssets(giveAssets_, takeData.giveAssets);
        _verifyGiveEvent(id_, takeData.giveProof);
        SafeERC20.safeTransfer(asset, takeData.takeReceiver, assets_ + rewardAssets_);
    }

    function _verifyGiveAssets(uint256 assets_, uint256 giveAssets_) private view {
        (uint256 commonAssets, uint256 commonGiveAssets) = DecimalsLib.common(assets_, giveAssets_, giveDecimalsShift);
        require(commonGiveAssets >= commonAssets, InsufficientGiveAssets(commonGiveAssets, commonAssets));
    }

    function _verifyGiveEvent(bytes32 giveHash_, bytes memory giveProof_) private {
        bytes32[] memory topics = new bytes32[](2);
        topics[0] = TRANSFER_GIVE_EVENT_SIGNATURE;
        topics[1] = giveHash_;
        verifier.verifyEvent(giveChain, giveTransferGiver, topics, "", giveProof_);
    }

    function _decodeData(bytes calldata data_) private pure returns (TransferTakeData calldata takeData) {
        assembly { takeData := data_.offset } // solhint-disable-line no-inline-assembly
    }
}
