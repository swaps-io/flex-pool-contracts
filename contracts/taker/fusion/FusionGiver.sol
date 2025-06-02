// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IEscrowFactory} from "@1inch/cross-chain-swap/contracts/interfaces/IEscrowFactory.sol";
import {TimelocksLib} from "@1inch/cross-chain-swap/contracts/libraries/TimelocksLib.sol";

import {MakerTraitsLib} from "@1inch/limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";
import {TakerTraitsLib} from "@1inch/limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";
import {ExtensionLib} from "@1inch/limit-order-protocol/contracts/libraries/ExtensionLib.sol";

import {AddressLib, Address as AddressSU} from "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";

import {PoolAware, IFlexPool} from "../../pool/aware/PoolAware.sol";

import {AssetPermitter} from "../../permit/AssetPermitter.sol";

import {AssetRescuer} from "../../rescue/AssetRescuer.sol";

import {Controllable} from "../../control/Controllable.sol";

import {TrackAsset} from "../../util/track/TrackAsset.sol";

import {IFusionGiver, IOrderMixin, TakerTraits, IEscrowSrc} from "./interfaces/IFusionGiver.sol";
import {IMerkleStorageInvalidator} from "./interfaces/IMerkleStorageInvalidator.sol";

contract FusionGiver is IFusionGiver, PoolAware, AssetPermitter, AssetRescuer, Controllable, TrackAsset {
    address public immutable override aggregationRouter;
    address public immutable override escrowFactory;

    mapping(address escrow => address) public override originalTaker;

    constructor(
        IFlexPool pool_,
        address controller_,
        address aggregationRouter_,
        address escrowFactory_
    )
        PoolAware(pool_)
        AssetPermitter(poolAsset)
        Controllable(controller_)
    {
        aggregationRouter = aggregationRouter_;
        escrowFactory = escrowFactory_;

        // Provide infinite allowance to the router. Any `msg.sender` interactions are limited by logic below, which is
        // designed to be safe - i.e. ensures to not spend extra assets during router interactions other than spending
        // assets provided for the call. This contract also won't verify any contract signature nor allow other ways to
        // obtain permit allowing to take the asset though the router.
        poolAsset.approve(aggregationRouter_, type(uint256).max);
    }

    modifier returnPoolAsset {
        _;
        _trackTokenAfter(poolAsset, 0);
    }

    modifier onlyOriginalTaker(address escrow_) {
        address taker = originalTaker[escrow_];
        require(msg.sender == taker, CallerNotOriginalTaker(msg.sender, escrow_, taker));
        _;
    }

    // ---

    function transferAssetToPool() public override returnPoolAsset {}

    // `IOrderMixin` compatibility

    function fillOrder(
        IOrderMixin.Order calldata order_,
        bytes32 /* r_ */,
        bytes32 /* vs_ */,
        uint256 amount_,
        TakerTraits /* takerTraits_ */
    ) public payable override returns (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) {
        return _fillEscrow(order_, amount_, _emptyExtension());
    }

    function fillOrderArgs(
        IOrderMixin.Order calldata order_,
        bytes32 /* r_ */,
        bytes32 /* vs_ */,
        uint256 amount_,
        TakerTraits takerTraits_,
        bytes calldata args_
    ) public payable override returns (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) {
        return _fillEscrow(order_, amount_, _extractExtension(takerTraits_, args_));
    }

    function fillContractOrder(
        IOrderMixin.Order calldata order_,
        bytes calldata /* signature_ */,
        uint256 amount_,
        TakerTraits /* takerTraits_ */
    ) public override returns (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) {
        return _fillEscrow(order_, amount_, _emptyExtension());
    }

    function fillContractOrderArgs(
        IOrderMixin.Order calldata order_,
        bytes calldata /* signature_ */,
        uint256 amount_,
        TakerTraits takerTraits_,
        bytes calldata args_
    ) public override returns (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) {
        return _fillEscrow(order_, amount_, _extractExtension(takerTraits_, args_));
    }

    // `IEscrowSrc` compatibility

    function withdraw(bytes32 secret_, IEscrowSrc.Immutables calldata immutables_) public override {
        withdrawEscrow(_predictEscrow(immutables_), secret_, immutables_);
    }

    function cancel(IEscrowSrc.Immutables calldata immutables_) public override {
        cancelEscrow(_predictEscrow(immutables_), immutables_);
    }

    function rescueFunds(address token_, uint256 amount_, IEscrowSrc.Immutables calldata immutables_) public override {
        rescueFundsEscrow(_predictEscrow(immutables_), token_, amount_, immutables_);
    }

    // `IEscrowSrc` using pre-calculated address

    function withdrawEscrow(
        address escrow_,
        bytes32 secret_,
        IEscrowSrc.Immutables calldata immutables_
    ) public override
        trackNative
        returnPoolAsset
    {
        IEscrowSrc(escrow_).withdraw(secret_, immutables_);
    }

    function cancelEscrow(address escrow_, IEscrowSrc.Immutables calldata immutables_) public override
        onlyOriginalTaker(escrow_)
        trackNative
        trackToken(poolAsset)
    {
        IEscrowSrc(escrow_).cancel(immutables_);
    }

    function rescueFundsEscrow(
        address escrow_,
        address token_,
        uint256 amount_,
        IEscrowSrc.Immutables calldata immutables_
    ) public override
        onlyOriginalTaker(escrow_)
        trackAsset(token_)
    {
        IEscrowSrc(escrow_).rescueFunds(token_, amount_, immutables_);
    }

    // ---

    function _canCallRescue(address caller_) internal view override returns (bool) {
        return caller_ == controller;
    }

    function _canRescueAsset(address asset_) internal view override returns (bool) {
        return asset_ != address(poolAsset);
    }

    // ---

    function _fillEscrow(
        IOrderMixin.Order calldata order_,
        uint256 amount_,
        bytes calldata extension_
    ) private
        trackNative
        trackToken(poolAsset)
        returns (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash)
    {
        SafeERC20.safeTransferFrom(poolAsset, msg.sender, address(this), amount_);

        (address listener, bytes calldata data) = _extractPostInteraction(order_, extension_);
        require(listener == escrowFactory, PostInteractionListenerNotEscrowFactory(listener, escrowFactory));

        bytes memory result = Address.functionCallWithValue(aggregationRouter, msg.data, msg.value);
        (makingAmount, takingAmount, orderHash) = abi.decode(result, (uint256, uint256, bytes32));

        IEscrowSrc.Immutables memory immutables = _extractEscrowSrcImmutables(order_, orderHash, makingAmount, data);
        require(
            AddressLib.get(immutables.token) == address(poolAsset),
            EscrowMakerAssetNotPool(AddressLib.get(immutables.token), address(poolAsset))
        );

        address escrow = _predictEscrow(immutables);
        originalTaker[escrow] = msg.sender;
    }

    function _predictEscrow(IEscrowSrc.Immutables memory immutables) private view returns (address) {
        return IEscrowFactory(escrowFactory).addressOfEscrowSrc(immutables);
    }

    function _emptyExtension() private pure returns (bytes calldata extension) {
        // Based on `AggregationRouterV6` implementation
        extension = msg.data[:0];
    }

    function _extractExtension(
        TakerTraits takerTraits_,
        bytes calldata args_
    ) private pure returns (bytes calldata extension) {
        // Based on `AggregationRouterV6._parseArgs` implementation
        if (TakerTraitsLib.argsHasTarget(takerTraits_)) {
            args_ = args_[20:];
        }

        uint256 extensionLength = TakerTraitsLib.argsExtensionLength(takerTraits_);
        if (extensionLength > 0) {
            extension = args_[:extensionLength];
        } else {
            extension = _emptyExtension();
        }
    }

    function _extractPostInteraction(
        IOrderMixin.Order calldata order_,
        bytes calldata extension_
    ) private pure returns (address listener, bytes calldata data) {
        // Based on `AggregationRouterV6._fill` implementation
        require(MakerTraitsLib.needPostInteractionCall(order_.makerTraits), NoPostInteractionCall(order_.makerTraits));

        data = ExtensionLib.postInteractionTargetAndData(extension_);
        listener = AddressLib.get(order_.maker);
        if (data.length > 19) {
            listener = address(bytes20(data));
            data = data[20:];
        }
    }

    function _extractEscrowSrcImmutables(
        IOrderMixin.Order calldata order_,
        bytes32 orderHash_,
        uint256 makingAmount_,
        bytes calldata extraData_
    ) private view returns (IEscrowSrc.Immutables memory immutables) {
        // Based on `BaseEscrowFactory._postInteraction` implementation
        IEscrowFactory.ExtraDataArgs calldata extraDataArgs = _extractExtraDataArgs(extraData_);
        bytes32 hashlock = _extractHashlock(order_, orderHash_, extraDataArgs);
        return _composeSrcImmutables(order_, orderHash_, makingAmount_, extraDataArgs, hashlock);
    }

    function _extractExtraDataArgs(
        bytes calldata extraData_
    ) private pure returns (IEscrowFactory.ExtraDataArgs calldata extraDataArgs) {
        // Based on `BaseEscrowFactory._postInteraction` implementation
        uint256 superArgsLength = extraData_.length - 160; // SRC_IMMUTABLES_LENGTH

        assembly ("memory-safe") { // solhint-disable-line no-inline-assembly
            extraDataArgs := add(extraData_.offset, superArgsLength)
        }
    }

    function _extractHashlock(
        IOrderMixin.Order calldata order_,
        bytes32 orderHash_,
        IEscrowFactory.ExtraDataArgs calldata extraDataArgs_
    ) private view returns (bytes32 hashlock) {
        // Based on `BaseEscrowFactory._postInteraction` implementation
        if (MakerTraitsLib.allowMultipleFills(order_.makerTraits)) {
            bytes32 key = keccak256(abi.encodePacked(orderHash_, uint240(uint256(extraDataArgs_.hashlockInfo))));
            (, hashlock) = IMerkleStorageInvalidator(escrowFactory).lastValidated(key);
        } else {
            hashlock = extraDataArgs_.hashlockInfo;
        }
    }

    function _composeSrcImmutables(
        IOrderMixin.Order calldata order_,
        bytes32 orderHash_,
        uint256 makingAmount_,
        IEscrowFactory.ExtraDataArgs calldata extraDataArgs_,
        bytes32 hashlock_
    ) private view returns (IEscrowSrc.Immutables memory immutables) {
        // Based on `BaseEscrowFactory._postInteraction` implementation
        immutables.orderHash = orderHash_;
        immutables.hashlock = hashlock_;
        immutables.maker = order_.maker;
        immutables.taker = AddressSU.wrap(uint160(address(this))); // Address.wrap(uint160(taker))
        immutables.token = order_.makerAsset;
        immutables.amount = makingAmount_;
        immutables.safetyDeposit = extraDataArgs_.deposits >> 128;
        immutables.timelocks = TimelocksLib.setDeployedAt(extraDataArgs_.timelocks, block.timestamp);
    }
}
