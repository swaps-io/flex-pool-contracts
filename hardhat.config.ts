import type { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox-viem';
import 'hardhat-contract-sizer';

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.28',
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 100_000,
      },
    },
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: true,
    runOnCompile: true,
    strict: true,
    only: [
      'contracts/pool/FlexPool.sol',
      'contracts/give/transfer/TransferGiveProvider.sol',
      'contracts/take/transfer/TransferTakeProvider.sol',
      'contracts/tune/linear/LinearTuneProvider.sol',

      'contracts/next/pool/FlexPoolNext.sol',
      'contracts/next/taker/transfer/TransferGiver.sol',
      'contracts/next/taker/transfer/TransferTaker.sol',
    ],
  },
};

export default config;
