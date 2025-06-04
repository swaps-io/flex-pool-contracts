<!-- omit in toc -->
# Flex Pool Contracts 🐳

Smart contracts of Flex Pool protocol.

<!-- omit in toc -->
### Table of Contents

- [Description](#description)
  - [Overview](#overview)
  - [Infrastructure](#infrastructure)
  - [Operations](#operations)
    - [Deposit](#deposit)
    - [Withdraw](#withdraw)
    - [Take](#take)
    - [Give](#give)
    - [Rebalance](#rebalance)
  - [Asset](#asset)
  - [Tuner](#tuner)
  - [Taker](#taker)
  - [Verifier](#verifier)
- [Providers](#providers)
  - [Transfer](#transfer)
  - [1inch Fusion+](#1inch-fusion)
- [Development](#development)
  - [Stack](#stack)
  - [Dependencies](#dependencies)
  - [Setup](#setup)
  - [Build](#build)
  - [Test](#test)
  - [Lint](#lint)

## Description

### Overview

Flex Pool Protocol allows solvers to [take](#take) the available pool [asset](#asset) on one chain and return it on
another chain via a [give](#give) operation. These operations are carried out through a variety of secure whitelisted
adapters to 3rd-party [providers](#providers).

Liquidity providers [deposit](#deposit) pool asset for protocol to cover the solver operations. In return, providers
receive pool "shares", that represent their participation in pool liquidity. A share is backed by more assets as the
pool protocol collects [fees](#tuner) from the solvers. Providers can [withdraw](#withdraw) the original asset back
from the "shares" as desired.

For a single logical asset, there is one pool on every supported chain. Pools are connected with each other by the
[infrastructure](#infrastructure). Liquidity can be moved within these per-asset infrastructure-isolated enclaves with
the take and give operations. If liquidity is not returned to its original chain naturally during these operations, the
[rebalance](#rebalance) mechanism provides an incentive for an arbitrary solver to restore the liquidity manually.

### Infrastructure

Main [`FlexPool`](contracts/pool/FlexPool.sol) contract contains controlled whitelist of all allowed [take](#take)
[providers](#providers) with attached [tuners](#tuner). Each taker is designed to guarantee a secure cross-chain
transfer of required liquidity amount between pools in one logical [asset](#asset) enclave.

Taker contract is bound to a specific 3rd-party provider. It's also often limited by deployment parameters to support
a single chain-to-chain channel for better security - especially when it needs to validate actions of a helper
[giver](#give) contract on the other chain. It follows that there may be several instances of one provider in the
router - one for every enclave chain.

Some provider implementations require verification of a certain event that occurred on the other chain to ensure
soundness of the take (or any related) operation. For the verification purpose, such a provider employs event
[verifier](#verifier) contract.

> [!TIP]
>
> _Pool infrastructure_
>
> ![Pool Infrastructure](data/images/pool-infra.svg)

### Operations

Pool implementation is based on tokenized vault standard [EIP-4626](https://eips.ethereum.org/EIPS/eip-4626).
It's recommended to look into it before diving into the pool operation specifics.

#### Deposit

> ---
>
> - Function: __`deposit`__ of [`IERC4626`](node_modules/@openzeppelin/contracts/interfaces/IERC4626.sol)
>
> - Params:
>   - `assets` (`uint256`) - amount of assets to deposit
>   - `receiver` (`address`) - minted shares receiver
>
> - Returns:
>   - `shares` (`uint256`) - amount of shares minted
>
> - Events:
>   - `Deposit`
>     - `sender` (`address`, _`indexed`_) - address of deposit caller
>     - `owner` (`address`, _`indexed`_) - deposited asset owner
>     - `assets` (`uint256`) - amount of deposited assets
>     - `shares` (`uint256`) - amount of deposited shares
>
> ---
>
> - Function: __`previewDeposit`__ (_`view`_) of
> [`IERC4626`](node_modules/@openzeppelin/contracts/interfaces/IERC4626.sol)
>
> - Params:
>   - `assets` (`uint256`) - amount of assets planned to deposit
>
> - Returns:
>   - `shares` (`uint256`) - amount of shares will be minted
>
> ---
>
> - Function: __`maxDeposit`__ (_`view`_) of [`IERC4626`](node_modules/@openzeppelin/contracts/interfaces/IERC4626.sol)
>
> - Params:
>   - `receiver` (`address`) - receiver of the deposit shares
>
> - Returns:
>   - `maxAssets` (`uint256`) - max amount of assets receiver can deposit
>
> ---

The `deposit` function allows liquidity providers to deposit desired amount of the pool [asset](#asset).
Specified amount of the asset is _received_ from the caller address, so sufficient
[ERC-20](https://ethereum.org/en/developers/docs/standards/tokens/erc-20) allowance must be provided for the pool
contract prior the call (various permit multicall options are supported).

Depositing asset mints "shares" to `receiver` address. The `previewDeposit` function can be used to pre-calculate the
amount of minted shares. Minted shares represent liquidity provider participation in pool. These shares are backed by
_at least_ deposited asset amount. As pool collects protocol fee, the collected fee is distributed between all the
providers proportionally.

> [!TIP]
>
> _Simplified example of protocol fee distribution_
>
> - _A_ deposits 500 of asset
>   - 50000 shares minted to _A_
>
> - _B_ deposits 1500 of asset
>   - 150000 shares minted to _B_
>
> - Withdrawable asset
>   - _A_: 50000 shares = 500 of asset
>   - _B_: 150000 shares = 1500 of asset
>
> - Pool receives fee of 500 asset
>   - Each share is backed by 0.01 -> 0.0125 of asset
>
> - Withdrawable asset
>   - _A_: 50000 shares = 625 of asset (+125)
>   - _B_: 150000 shares = 1875 of asset (+375)
>
> - _C_ deposits 2500 of asset
>   - 200000 shares minted to _C_
>
> - Withdrawable asset
>   - _A_: 50000 shares = 625 of asset (+125)
>   - _B_: 150000 shares = 1875 of asset (+375)
>   - _C_: 200000 shares = 2500 of asset
>
> - Pool receives fee of 2000 asset
>   - Each share is backed by 0.0125 -> 0.0175 of asset
>
> - Withdrawable asset
>   - _A_: 50000 shares = 875 of asset (+125, +250)
>   - _B_: 150000 shares = 2625 of asset (+375, +750)
>   - _C_: 200000 shares = 3500 of asset (+1000)
>
> - This state can be observed in real pool with
>   - `pool.balanceOf(<user>)` (ERC-20) - shares balance of user
>   - `pool.totalSupply()` (ERC-20) - total shares minted
>   - `pool.totalAssets()` (ERC-4626) - [total assets](#total-assets) managed
>   - `pool.convertToShares(<assets>)` (ERC-4626) - convert helper
>   - `pool.convertToAssets(<shares>)` (ERC-4626) - convert helper

Shares behave exactly like usual ERC-20 token (sharing the address with the pool contract address), but have different
number of decimals than the managed asset, [permit](https://eips.ethereum.org/EIPS/eip-2612) support, and accepted by
the pool for [withdraw](#withdraw) operation to convert back to the asset.

While `maxDeposit` function is presented as part of the [EIP-4626](https://eips.ethereum.org/EIPS/eip-4626)
implementation, there is _no actual limit_ implemented in the pool protocol logic. TODO

> [!NOTE]
>
> There is an alternative set of functions in [`ERC-4626`](node_modules/@openzeppelin/contracts/interfaces/IERC4626.sol)
> that allows to specify deposit amount in shares instead of assets.

> ---
>
> - Function: __`mint`__ of [`IERC4626`](node_modules/@openzeppelin/contracts/interfaces/IERC4626.sol)
>
> - Params:
>   - `shares` (`uint256`) - amount of shares to mint
>   - `receiver` (`address`) - minted shares receiver
>
> - Returns:
>   - `assets` (`uint256`) - amount of asset to deposit
>
> - Events:
>   - `Deposit`
>     - `sender` (`address`, _`indexed`_) - address of deposit caller
>     - `owner` (`address`, _`indexed`_) - deposited asset owner
>     - `assets` (`uint256`) - amount of deposited assets
>     - `shares` (`uint256`) - amount of deposited shares
>
> ---
>
> - Function: __`previewMint`__ (_`view`_) of [`IERC4626`](node_modules/@openzeppelin/contracts/interfaces/IERC4626.sol)
>
> - Params:
>   - `shares` (`uint256`) - amount of shares planned to mint
>
> - Returns:
>   - `assets` (`uint256`) - amount of deposit assets
>
> ---
>
> - Function: __`maxMint`__ (_`view`_) of [`IERC4626`](node_modules/@openzeppelin/contracts/interfaces/IERC4626.sol)
>
> - Params:
>   - `receiver` (`address`) - receiver of mint shares
>
> - Returns:
>   - `maxShares` (`uint256`) - max amount of shares can be minted
>
> ---

#### Withdraw

> ---
>
> - Function: __`withdraw`__ of [`IERC4626`](node_modules/@openzeppelin/contracts/interfaces/IERC4626.sol)
>
> - Params:
>   - `assets` (`uint256`) - amount of assets to withdraw
>   - `receiver` (`address`) - withdrawn asset receiver
>   - `owner` (`address`) - owner to take shares from
>
> - Returns:
>   - `shares` (`uint256`) - amount of shares withdrawn
>
> - Events:
>   - `Withdraw`
>     - `sender` (`address`, _`indexed`_) - address of withdraw caller
>     - `receiver` (`address`, _`indexed`_) - withdrawn asset receiver
>     - `owner` (`address`, _`indexed`_) - withdrawn asset owner
>     - `assets` (`uint256`) - amount of withdrawn asset
>     - `shares` (`uint256`) - amount of withdrawn shares
>
> ---
>
> - Function: __`previewWithdraw`__ (_`view`_) of
> [`IERC4626`](node_modules/@openzeppelin/contracts/interfaces/IERC4626.sol)
>
> - Params:
>   - `assets` (`uint256`) - amount of assets planned to withdraw
>
> - Returns:
>   - `shares` (`uint256`) - amount of shares will be withdrawn
>
> ---
>
> - Function: __`maxWithdraw`__ (_`view`_) of [`IERC4626`](node_modules/@openzeppelin/contracts/interfaces/IERC4626.sol)
>
> - Params:
>   - `owner` (`address`) - owner of shares to withdraw
>
> - Returns:
>   - `maxAssets` (`uint256`) - max amount of assets owner can withdraw
>
> ---

The `withdraw` function allows to burn [deposit](#deposit)-minted shares of `owner` and get asset these shares are
currently backed by. Amount of the resulting withdraw asset can be checked using `previewWithdraw`.

Since shares represented by special pool token, withdrawing does not require ERC-20 allowance provisioning. However,
when an arbitrary account has shares allowance provided by `owner`, they can call withdraw asset on owner's behalf.

The `maxWithdraw` function only limits withdraw amount by owner's shares balance.

> [!IMPORTANT]
>
> While it's possible to withdraw entire shares balance instantly, it's _not guaranteed_ that all withdrawn assets will
> be sent to `receiver` immediately. TODO: update w/ available assets

This is due to the fact that pool liquidity can currently be taken to another chain and not given back to this chain
yet. TODO: update w/ available assets

> [!NOTE]
>
> There is an alternative set of functions in [`ERC-4626`](node_modules/@openzeppelin/contracts/interfaces/IERC4626.sol)
> that allows to specify withdraw amount in shares instead of assets.

> ---
>
> - Function: __`redeem`__ of [`IERC4626`](node_modules/@openzeppelin/contracts/interfaces/IERC4626.sol)
>
> - Params:
>   - `shares` (`uint256`) - amount of shares to withdraw
>   - `receiver` (`address`) - withdrawn asset receiver
>   - `owner` (`address`) - owner to take shares from
>
> - Returns:
>   - `assets` (`uint256`) - amount of asset withdrawn
>
> - Events:
>   - `Withdraw`
>     - `sender` (`address`, _`indexed`_) - address of withdraw caller
>     - `receiver` (`address`, _`indexed`_) - withdrawn asset receiver
>     - `owner` (`address`, _`indexed`_) - withdrawn asset owner
>     - `assets` (`uint256`) - amount of withdrawn asset
>     - `shares` (`uint256`) - amount of withdrawn shares
>
> ---
>
> - Function: __`previewRedeem`__ (_`view`_) of
> [`IERC4626`](node_modules/@openzeppelin/contracts/interfaces/IERC4626.sol)
>
> - Params:
>   - `shares` (`uint256`) - amount of shares planned to withdraw
>
> - Returns:
>   - `assets` (`uint256`) - amount of asset will be withdrawn
>
> ---
>
> - Function: __`maxRedeem`__ (_`view`_) of [`IERC4626`](node_modules/@openzeppelin/contracts/interfaces/IERC4626.sol)
>
> - Params:
>   - `owner` (`address`) - owner of shares to withdraw
>
> - Returns:
>   - `maxShares` (`uint256`) - max amount of shares owner can withdraw
>
> ---

#### Take

TODO

#### Give

TODO

#### Rebalance

TODO

### Asset

TODO

### Tuner

TODO

### Taker

TODO

### Verifier

TODO

## Providers

TODO

### Transfer

TODO

### 1inch Fusion+

TODO

## Development

### Stack

- __Language__: Solidity v0.8.28+
- __Framework__: Hardhat v2+
- __Node.js__: v22.14+
- __Yarn__: v4.9+

### Dependencies

| Name | Version | Provision | Scope | Purpose |
|------|---------|-----------|-------|---------|
| [`@openzeppelin/contracts`](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/e4f70216d759d8e6a64144a9e1f7bbeed78e7079) | `5.3.0` | [NPM package](https://www.npmjs.com/package/@openzeppelin/contracts/v/5.3.0) | Global | Common utilities |
| [`@1inch/cross-chain-swap`](https://github.com/1inch/cross-chain-swap/tree/ac885535b572e85526bae10485ca64b449005ee2) | `1.0.0` | [Submodule](submodules/1inch/cross-chain-swap) | [`taker/fusion`](contracts/taker/fusion) | [1inch Fusion+ taker provider](#1inch-fusion) |

### Setup

Before setup:
- Ensure [recommended](#stack) version of [Node.js](https://nodejs.org) is installed
- Follow [Yarn installation](https://yarnpkg.com/getting-started/install) if needed
- Check `git` and `patch` utils are available on machine

> [!TIP]
>
> Use [NVM](https://github.com/nvm-sh/nvm) to switch to recommended version of Node.js: `nvm use`

Setup project:
- Initialize submodules: `git submodule update --init --recursive`
- Apply code patches: `patch <patch.diff`
- Install dependencies: `yarn`

### Build

To build (i.e. compile) contracts, run `yarn build`.

> [!TIP]
>
> Shortcut available: `yarn b`.

### Test

To test contacts, run `yarn test`. Note useful `--no-compile` and `--grep <pattern>` options for debugging provided by
[Hardhat](https://hardhat.org/).

> [!TIP]
>
> Shortcuts available:
> - `yarn t`
> - `yarn tg` (`--grep`)
> - `yarn tn` (`--no-compile`)
> - `yarn tng` / `yarn tgn`

### Lint

To lint contracts, run `yarn lint`.

> [!TIP]
>
> Shortcut available: `yarn l`.
