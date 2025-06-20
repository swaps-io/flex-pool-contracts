import type { HardhatUserConfig } from 'hardhat/config';
import { SolcUserConfig } from 'hardhat/types';
import '@nomicfoundation/hardhat-toolbox-viem';
import 'hardhat-contract-sizer';

const solc = (): SolcUserConfig => {
  return {
    version: '0.8.28',
    settings: {
      viaIR: true,
      evmVersion: process.env.EVM_VERSION ?? 'cancun', // `EVM_VERSION=paris yarn build`
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
      'contracts/taker/cctp/CctpTaker.sol',
      'contracts/taker/fusion/FusionGiver.sol',
      'contracts/taker/fusion/FusionTaker.sol',
      'contracts/taker/transfer/TransferGiver.sol',
      'contracts/taker/transfer/TransferTaker.sol',
    ],
  },
};

export default config;
