import { loadFixture, } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers';
import hre from 'hardhat';
import { expect } from 'chai';
import { checksumAddress, encodeAbiParameters, parseAbiParameters, parseEventLogs, zeroAddress } from 'viem';

const TEST_TUNE_DATA_ABI = parseAbiParameters([
  'TestTuneData',
  'struct TestTuneData { uint256 assets; uint256 protocolAssets; int256 rebalanceAssets; }',
]);
const TEST_TAKE_DATA_ABI = parseAbiParameters([
  'TestTakeData',
  'struct TestTakeData { bytes32 id; address caller; uint256 assets; uint256 rewardAssets; uint256 giveAssets; uint256 value; }',
]);

describe('FlexPool', function () {
  async function deployFixture() {
    const publicClient = await hre.viem.getPublicClient();
    const [ownerClient, regularClient] = await hre.viem.getWalletClients();

    const asset = await hre.viem.deployContract('TestToken', [
      'Test Token', // name
      'TT', // symbol
      6, // decimals
    ]);

    const pool = await hre.viem.deployContract('FlexPool', [
      asset.address, // asset
      'Pool Test Token', // name
      'PTT', // symbol
      18, // decimalsOffset
      ownerClient.account.address, // initialOwner
    ]);

    const taker = await hre.viem.deployContract('TestTaker');

    const tuner = await hre.viem.deployContract('TestTuner');

    return {
      publicClient,
      ownerClient,
      regularClient,
      asset,
      pool,
      taker,
      tuner,
    };
  }

  it('Should have code', async function () {
    const { publicClient, pool } = await loadFixture(deployFixture);

    const code = await publicClient.getCode({ address: pool.address });
    expect(code?.length ?? 0).greaterThan(0);
    console.log(`Code: ${code}`);
  });

  it('Should not allow unknown taker', async function () {
    const { pool, regularClient } = await loadFixture(deployFixture);

    const taker = '0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF';

    await expect(
      regularClient.writeContract({
        abi: pool.abi,
        address: pool.address,
        functionName: 'take',
        args: [
          1n, // assets
          taker, // taker
          '0x', // takerData
          '0x', // tunerData
        ],
      }),
    ).rejectedWith(`NoTuner("${taker}")`);
  });

  it('Should not allow regular to add taker', async function () {
    const { pool, regularClient, ownerClient } = await loadFixture(deployFixture);

    const taker = '0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF';
    const tuner = '0xC0Dec0dec0DeC0Dec0dEc0DEC0DEC0DEC0DEC0dE';
    const caller = checksumAddress(regularClient.account.address);
    const controller = checksumAddress(ownerClient.account.address);

    await expect(
      regularClient.writeContract({
        abi: pool.abi,
        address: pool.address,
        functionName: 'setTuner',
        args: [
          taker, // taker
          tuner, // tuner
        ],
      }),
    ).rejectedWith(`CallerNotController("${caller}", "${controller}")`);
  });

  it('Should allow owner to add taker', async function () {
    const { pool, ownerClient, publicClient } = await loadFixture(deployFixture);

    const taker = '0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF';
    const tuner = '0xC0Dec0dec0DeC0Dec0dEc0DEC0DEC0DEC0DEC0dE';

    const hash = await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        taker, // taker
        tuner, // tuner
      ],
    });

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`FlexPool.setTuner add gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: pool.abi,
      logs: receipt.logs,
      eventName: 'TunerUpdate',
      args: {
        taker,
        oldTuner: zeroAddress,
        newTuner: tuner,
      },
    });
    expect(logs.length).equal(1);
  });

  it('Should allow owner to update taker', async function () {
    const { pool, ownerClient, publicClient } = await loadFixture(deployFixture);

    const taker = '0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF';
    const tuner = '0xC0Dec0dec0DeC0Dec0dEc0DEC0DEC0DEC0DEC0dE';
    const nextTuner = '0xBeEbeEBEEBeEBeebeebEEBEebEebEeBEEbEeBeEB';

    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        taker, // taker
        tuner, // tuner
      ],
    });

    const hash = await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        taker, // taker
        nextTuner, // tuner
      ],
    });

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`FlexPool.setTuner update gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: pool.abi,
      logs: receipt.logs,
      eventName: 'TunerUpdate',
      args: {
        taker,
        oldTuner: tuner,
        newTuner: nextTuner,
      },
    });
    expect(logs.length).equal(1);
  });

  it('Should allow owner to remove taker', async function () {
    const { pool, ownerClient, publicClient } = await loadFixture(deployFixture);

    const taker = '0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF';
    const tuner = '0xC0Dec0dec0DeC0Dec0dEc0DEC0DEC0DEC0DEC0dE';

    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        taker, // taker
        tuner, // tuner
      ],
    });

    const hash = await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        taker, // taker
        zeroAddress, // tuner
      ],
    });

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`FlexPool.setTuner remove gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: pool.abi,
      logs: receipt.logs,
      eventName: 'TunerUpdate',
      args: {
        taker,
        oldTuner: tuner,
        newTuner: zeroAddress,
      },
    });
    expect(logs.length).equal(1);
  });

  it('Should allow added taker', async function () {
    const { asset, pool, taker, tuner, publicClient, regularClient, ownerClient } = await loadFixture(deployFixture);

    const id = '0x1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d';
    const value = 123_456n;
    const assets = 133_701_337n;
    const protocolAssets = 3_302n;
    const rebalanceAssets = 137_137n;
    const takerData = encodeAbiParameters(TEST_TAKE_DATA_ABI, [{
      id,
      caller: regularClient.account.address,
      assets,
      rewardAssets: 0n,
      giveAssets: assets + protocolAssets + rebalanceAssets,
      value,
    }]);
    const tunerData = encodeAbiParameters(TEST_TUNE_DATA_ABI, [{
      assets,
      protocolAssets,
      rebalanceAssets,
    }]);

    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        taker.address, // taker
        tuner.address, // tuner
      ],
    });

    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        pool.address, // account
        assets * 2n, // assets
      ],
    });

    const hash = await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'take',
      args: [
        assets, // assets
        taker.address, // taker
        takerData, // takerData
        tunerData, // tunerData
      ],
      value,
    });

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`FlexPool.take test gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: pool.abi,
      logs: receipt.logs,
      eventName: 'Take',
      args: {
        id,
      },
    });
    expect(logs.length).equal(1);
  });
});
