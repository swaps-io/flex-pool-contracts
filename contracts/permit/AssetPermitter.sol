// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {IDaiPermit} from "./interfaces/IDaiPermit.sol";
import {IAssetPermitter, IERC20} from "./interfaces/IAssetPermitter.sol";
import {IPermit2, PermitTransferFrom, TokenPermissions, SignatureTransferDetails} from "./interfaces/IPermit2.sol";
import {IGnosisSafe} from "./interfaces/IGnosisSafe.sol";

abstract contract AssetPermitter is IAssetPermitter {
    address private constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    IERC20 public immutable permitAsset;

    constructor(IERC20 permitAsset_) {
        permitAsset = permitAsset_;
    }

    function usePermit(address from_, uint256 amount_, uint256 deadline_, bytes32 r_, bytes32 vs_) external {
        (bytes32 s, uint8 v) = _unpackVs(vs_);
        try IERC20Permit(address(permitAsset)).permit(
            from_,
            address(this),
            amount_,
            deadline_,
            v,
            r_,
            s
        ) {} catch {}
    }

    function useDaiPermit(address from_, bool allowed_, uint256 deadline_, bytes32 r_, bytes32 vs_) external {
        uint256 nonce = IDaiPermit(address(permitAsset)).nonces(from_);
        (bytes32 s, uint8 v) = _unpackVs(vs_);
        try IDaiPermit(address(permitAsset)).permit(
            from_,
            address(this),
            nonce,
            deadline_,
            allowed_,
            v,
            r_,
            s
        ) {} catch {}
    }

    function useUniswapPermit(address from_, uint256 amount_, uint256 deadline_, bytes calldata signature_) external {
        uint256 nonce = uint256(keccak256(abi.encodePacked(permitAsset, from_, amount_, deadline_, address(this))));
        try IPermit2(PERMIT2).permitTransferFrom(
            PermitTransferFrom({
                permitted: TokenPermissions({
                    token: address(permitAsset),
                    amount: amount_
                }),
                nonce: nonce,
                deadline: deadline_
            }),
            SignatureTransferDetails({
                to: address(this),
                requestedAmount: amount_
            }),
            from_,
            signature_
        ) {} catch {}
    }

    function useSafePermit(address from_, uint256 amount_, bytes calldata signature_) external {
        bytes memory data = abi.encodeCall(IERC20.approve, (address(this), amount_));
        try IGnosisSafe(from_).execTransaction(
            address(permitAsset), // to
            0, // value
            data, // data
            IGnosisSafe.Operation.Call, // operation
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            payable(0), // refundReceiver
            signature_ // signature
        ) {} catch {}
    }

    // Based on OpenZeppelin library (v5.3.0) internal implementation.
    // See "tryRecover(bytes32,bytes32,bytes32)" in "ECDSA.sol".
    function _unpackVs(bytes32 vs_) private pure returns (bytes32 s, uint8 v) {
        unchecked {
            s = vs_ & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            v = uint8((uint256(vs_) >> 255) + 27);
        }
    }
}
