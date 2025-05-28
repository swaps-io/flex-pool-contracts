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
        runs: 1_000_000,
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
      'contracts/tuner/linear/LinearTuner.sol',
      'contracts/taker/transfer/TransferGiver.sol',
      'contracts/taker/transfer/TransferTaker.sol',
    ],
  },
};

export default config;
