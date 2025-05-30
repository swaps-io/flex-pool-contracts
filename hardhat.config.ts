import type { HardhatUserConfig } from 'hardhat/config';
import { SolcUserConfig } from 'hardhat/types';
import '@nomicfoundation/hardhat-toolbox-viem';
import 'hardhat-contract-sizer';
import 'hardhat-preprocessor';

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

const remap = (line: string, search: string, replace: string, path: string): string => {
  if (!line.includes(search)) {
    return line;
  }

  const before = line;
  line = line.replace(search, replace);

  const dpos = path.indexOf(__dirname);
  const file = dpos < 0 ? path : path.slice(dpos + __dirname.length);

  console.log(`Remap '${search}' -> '${replace}' in '${file}':`);
  console.log(`- ${before}`);
  console.log(`+ ${line}`);
  console.log();

  return line;
}

const config: HardhatUserConfig = {
  solidity: {
    compilers: [solc()],
    overrides: {
      'contracts/pool/FlexPoolCancun.sol': solc({ evmVersion: 'cancun' }),
      '@openzeppelin/contracts/utils/TransientSlot.sol': solc({ evmVersion: 'cancun' }),
    },
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: true,
    runOnCompile: true,
    strict: true,
    only: [
      'contracts/pool/FlexPool.sol',
      'contracts/pool/FlexPoolCancun.sol',
      'contracts/tuner/linear/LinearTuner.sol',
      'contracts/taker/transfer/TransferGiver.sol',
      'contracts/taker/transfer/TransferTaker.sol',
      'contracts/taker/fusion/FusionGiver.sol',
      'contracts/taker/fusion/FusionTaker.sol',
    ],
  },
  preprocess: {
    eachLine: () => ({
      transform: (line: string, source) => {
        if (line.includes('import')) {
          return remap(line, '"solidity-utils', '"@1inch/solidity-utils', source.absolutePath);
        }
        return line;
      },
    }),
  },
};

export default config;
