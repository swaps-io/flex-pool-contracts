import type { HardhatUserConfig } from 'hardhat/config';
import { SolcUserConfig } from 'hardhat/types';
import '@nomicfoundation/hardhat-toolbox-viem';
import 'hardhat-contract-sizer';

type SolcOverrides = {
  evmVersion?: string;
}

const solc = (overrides: SolcOverrides = {}): SolcUserConfig => {
  return {
    version: '0.8.28',
    settings: {
      viaIR: true,
      evmVersion: overrides.evmVersion ?? 'paris',
      optimizer: {
        enabled: true,
        runs: 1_000_000,
      },
    },
  };
};

const config: HardhatUserConfig = {
  solidity: {
    compilers: [solc()],
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: true,
    runOnCompile: true,
    strict: true,
    only: [
      'contracts/pool/FlexPool.sol',
      'contracts/tuner/linear/LinearTuner.sol',
      'contracts/taker/across/AcrossDepositTaker.sol',
      'contracts/taker/across/AcrossFillTaker.sol',
      'contracts/taker/fusion/FusionGiver.sol',
      'contracts/taker/fusion/FusionTaker.sol',
      'contracts/taker/transfer/TransferGiver.sol',
      'contracts/taker/transfer/TransferTaker.sol',
    ],
  },
};

export default config;
