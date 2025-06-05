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
  'struct TestTakeData { bytes32 id; address caller; uint256 assets; uint256 surplusAssets; uint256 giveAssets; uint256 value; }',
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
      surplusAssets: 0n,
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

    expect(await publicClient.readContract({
      abi: taker.abi,
      address: taker.address,
      functionName: 'taken',
      args: [id],
    })).equal(false);

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

    expect(await publicClient.readContract({
      abi: taker.abi,
      address: taker.address,
      functionName: 'taken',
      args: [id],
    })).equal(true);

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`FlexPool.take test gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: pool.abi,
      logs: receipt.logs,
      eventName: 'Take',
      args: {
        taker: taker.address,
        assets,
        protocolAssets,
        rebalanceAssets,
      },
    });
    expect(logs.length).equal(1);
  });

  it('Should perform deposit', async function () {
    const { asset, pool, publicClient, regularClient, ownerClient } = await loadFixture(deployFixture);

    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        regularClient.account.address, // account
        80_000_000n, // assets
      ],
    });

    await regularClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'approve',
      args: [
        pool.address, // spender
        50_000_000n, // value
      ],
    });

    const hash = await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'deposit',
      args: [
        50_000_000n, // assets
        regularClient.account.address, // receiver
      ],
    });

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`FlexPool.deposit gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: pool.abi,
      logs: receipt.logs,
      eventName: 'Deposit',
      args: {
        sender: regularClient.account.address,
        owner: regularClient.account.address,
        assets: 50_000_000n,
        shares: 50_000_000_000000000000000000n,
      },
    });
    expect(logs.length).equal(1);

    const depositorAssets = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        regularClient.account.address, // account
      ],
    });
    expect(depositorAssets).equal(30_000_000n);

    const depositorShares = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'balanceOf',
      args: [
        regularClient.account.address, // account
      ],
    });
    expect(depositorShares).equal(50_000_000_000000000000000000n);

    const poolAssets = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        pool.address, // account
      ],
    });
    expect(poolAssets).equal(50_000_000n);

    const poolCurrentAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'currentAssets',
      args: [],
    });
    expect(poolCurrentAssets).equal(50_000_000n);

    const poolEquilibriumAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'equilibriumAssets',
      args: [],
    });
    expect(poolEquilibriumAssets).equal(0n);

    const poolAvailableAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'availableAssets',
      args: [],
    });
    expect(poolAvailableAssets).equal(50_000_000n);

    const poolRebalanceAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'rebalanceAssets',
      args: [],
    });
    expect(poolRebalanceAssets).equal(0n);
  });

  it('Should perform second deposit', async function () {
    const { asset, pool, publicClient, regularClient, ownerClient } = await loadFixture(deployFixture);

    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        regularClient.account.address, // account
        80_000_000n, // assets
      ],
    });

    await regularClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'approve',
      args: [
        pool.address, // spender
        60_000_000n, // value
      ],
    });

    // First
    await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'deposit',
      args: [
        50_000_000n, // assets
        regularClient.account.address, // receiver
      ],
    });

    // Second
    const hash = await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'deposit',
      args: [
        10_000_000n, // assets
        regularClient.account.address, // receiver
      ],
    });

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`FlexPool.deposit second gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: pool.abi,
      logs: receipt.logs,
      eventName: 'Deposit',
      args: {
        sender: regularClient.account.address,
        owner: regularClient.account.address,
        assets: 10_000_000n,
        shares: 10_000_000_000000000000000000n,
      },
    });
    expect(logs.length).equal(1);

    const depositorAssets = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        regularClient.account.address, // account
      ],
    });
    expect(depositorAssets).equal(20_000_000n);

    const depositorShares = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'balanceOf',
      args: [
        regularClient.account.address, // account
      ],
    });
    expect(depositorShares).equal(60_000_000_000000000000000000n);

    const poolAssets = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        pool.address, // account
      ],
    });
    expect(poolAssets).equal(60_000_000n);

    const poolCurrentAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'currentAssets',
      args: [],
    });
    expect(poolCurrentAssets).equal(60_000_000n);

    const poolEquilibriumAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'equilibriumAssets',
      args: [],
    });
    expect(poolEquilibriumAssets).equal(0n);

    const poolAvailableAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'availableAssets',
      args: [],
    });
    expect(poolAvailableAssets).equal(60_000_000n);

    const poolRebalanceAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'rebalanceAssets',
      args: [],
    });
    expect(poolRebalanceAssets).equal(0n);
  });

  it('Should perform withdraw', async function () {
    const { asset, pool, publicClient, regularClient, ownerClient } = await loadFixture(deployFixture);

    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        regularClient.account.address, // account
        80_000_000n, // assets
      ],
    });

    await regularClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'approve',
      args: [
        pool.address, // spender
        50_000_000n, // value
      ],
    });

    await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'deposit',
      args: [
        50_000_000n, // assets
        regularClient.account.address, // receiver
      ],
    });

    const hash = await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'withdraw',
      args: [
        30_000_000n, // assets
        regularClient.account.address, // receiver
        regularClient.account.address, // owner
      ],
    });

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`FlexPool.withdraw partial gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: pool.abi,
      logs: receipt.logs,
      eventName: 'Withdraw',
      args: {
        sender: regularClient.account.address,
        receiver: regularClient.account.address,
        owner: regularClient.account.address,
        assets: 30_000_000n,
        shares: 30_000_000_000000000000000000n,
      },
    });
    expect(logs.length).equal(1);

    const depositorAssets = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        regularClient.account.address, // account
      ],
    });
    expect(depositorAssets).equal(60_000_000n);

    const depositorShares = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'balanceOf',
      args: [
        regularClient.account.address, // account
      ],
    });
    expect(depositorShares).equal(20_000_000_000000000000000000n);

    const poolAssets = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        pool.address, // account
      ],
    });
    expect(poolAssets).equal(20_000_000n);

    const poolCurrentAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'currentAssets',
      args: [],
    });
    expect(poolCurrentAssets).equal(20_000_000n);

    const poolEquilibriumAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'equilibriumAssets',
      args: [],
    });
    expect(poolEquilibriumAssets).equal(0n);

    const poolAvailableAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'availableAssets',
      args: [],
    });
    expect(poolAvailableAssets).equal(20_000_000n);

    const poolRebalanceAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'rebalanceAssets',
      args: [],
    });
    expect(poolRebalanceAssets).equal(0n);
  });

  it('Should perform second withdraw', async function () {
    const { asset, pool, publicClient, regularClient, ownerClient } = await loadFixture(deployFixture);

    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        regularClient.account.address, // account
        80_000_000n, // assets
      ],
    });

    await regularClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'approve',
      args: [
        pool.address, // spender
        50_000_000n, // value
      ],
    });

    await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'deposit',
      args: [
        50_000_000n, // assets
        regularClient.account.address, // receiver
      ],
    });

    // First
    await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'withdraw',
      args: [
        30_000_000n, // assets
        regularClient.account.address, // receiver
        regularClient.account.address, // owner
      ],
    });

    // Second
    const hash = await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'withdraw',
      args: [
        10_000_000n, // assets
        regularClient.account.address, // receiver
        regularClient.account.address, // owner
      ],
    });

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`FlexPool.withdraw second partial gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: pool.abi,
      logs: receipt.logs,
      eventName: 'Withdraw',
      args: {
        sender: regularClient.account.address,
        receiver: regularClient.account.address,
        owner: regularClient.account.address,
        assets: 10_000_000n,
        shares: 10_000_000_000000000000000000n,
      },
    });
    expect(logs.length).equal(1);

    const depositorAssets = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        regularClient.account.address, // account
      ],
    });
    expect(depositorAssets).equal(70_000_000n);

    const depositorShares = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'balanceOf',
      args: [
        regularClient.account.address, // account
      ],
    });
    expect(depositorShares).equal(10_000_000_000000000000000000n);

    const poolAssets = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        pool.address, // account
      ],
    });
    expect(poolAssets).equal(10_000_000n);

    const poolCurrentAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'currentAssets',
      args: [],
    });
    expect(poolCurrentAssets).equal(10_000_000n);

    const poolEquilibriumAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'equilibriumAssets',
      args: [],
    });
    expect(poolEquilibriumAssets).equal(0n);

    const poolAvailableAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'availableAssets',
      args: [],
    });
    expect(poolAvailableAssets).equal(10_000_000n);

    const poolRebalanceAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'rebalanceAssets',
      args: [],
    });
    expect(poolRebalanceAssets).equal(0n);
  });

  it('Should perform take of deposit', async function () {
    const { asset, pool, taker, tuner, publicClient, regularClient, ownerClient } = await loadFixture(deployFixture);

    const id = '0x1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d';
    const depositAssets = 5_000_000_000n;
    const mintAssets = depositAssets + 3_000_000_000n;
    const value = 123_456n;
    const assets = 133_701_337n;
    const protocolAssets = 3_302n;
    const rebalanceAssets = 137_137n;
    const takerData = encodeAbiParameters(TEST_TAKE_DATA_ABI, [{
      id,
      caller: regularClient.account.address,
      assets,
      surplusAssets: 0n,
      giveAssets: assets + protocolAssets + rebalanceAssets,
      value,
    }]);
    const tunerData = encodeAbiParameters(TEST_TUNE_DATA_ABI, [{
      assets,
      protocolAssets,
      rebalanceAssets,
    }]);

    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        regularClient.account.address, // account
        mintAssets, // assets
      ],
    });
    await regularClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'approve',
      args: [
        pool.address, // spender
        depositAssets, // value
      ],
    });
    await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'deposit',
      args: [
        depositAssets, // assets
        regularClient.account.address, // receiver
      ],
    });
    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        taker.address, // taker
        tuner.address, // tuner
      ],
    });

    expect(await publicClient.readContract({
      abi: taker.abi,
      address: taker.address,
      functionName: 'taken',
      args: [id],
    })).equal(false);

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

    expect(await publicClient.readContract({
      abi: taker.abi,
      address: taker.address,
      functionName: 'taken',
      args: [id],
    })).equal(true);

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`FlexPool.take deposit gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: pool.abi,
      logs: receipt.logs,
      eventName: 'Take',
      args: {
        taker: taker.address,
        assets,
        protocolAssets,
        rebalanceAssets,
      },
    });
    expect(logs.length).equal(1);

    const takerAssets = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        taker.address, // account
      ],
    });
    expect(takerAssets).equal(assets);

    const takerNative = await publicClient.getBalance({ address: taker.address });
    expect(takerNative).equal(value);

    const poolAssets = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        pool.address, // account
      ],
    });
    expect(poolAssets).equal(depositAssets - assets);

    const poolCurrentAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'currentAssets',
      args: [],
    });
    expect(poolCurrentAssets).equal(depositAssets - assets);

    const poolEquilibriumAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'equilibriumAssets',
      args: [],
    });
    expect(poolEquilibriumAssets).equal(-(assets + protocolAssets + rebalanceAssets));

    const poolAvailableAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'availableAssets',
      args: [],
    });
    expect(poolAvailableAssets).equal(depositAssets - (assets + rebalanceAssets));

    const poolRebalanceAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'rebalanceAssets',
      args: [],
    });
    expect(poolRebalanceAssets).equal(rebalanceAssets);

    const depositorAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'previewRedeem',
      args: [
        await publicClient.readContract({
          abi: pool.abi,
          address: pool.address,
          functionName: 'balanceOf',
          args: [
            regularClient.account.address, // account
          ],
        }), // shares
      ],
    });
    expect(depositorAssets).equal(depositAssets + protocolAssets - 1n); // Gets all protocol assets as the only depositor
  });

  it('Should perform second take of deposit', async function () {
    const { asset, pool, taker, tuner, publicClient, regularClient, ownerClient } = await loadFixture(deployFixture);

    const firstId = '0x0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d';
    const id = '0x1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d';
    const depositAssets = 5_000_000_000n;
    const mintAssets = depositAssets + 3_000_000_000n;
    const value = 123_456n;
    const assets = 133_701_337n;
    const protocolAssets = 3_302n;
    const rebalanceAssets = 137_137n;
    const firstTakerData = encodeAbiParameters(TEST_TAKE_DATA_ABI, [{
      id: firstId,
      caller: regularClient.account.address,
      assets,
      surplusAssets: 0n,
      giveAssets: assets + protocolAssets + rebalanceAssets,
      value,
    }]);
    const takerData = encodeAbiParameters(TEST_TAKE_DATA_ABI, [{
      id,
      caller: regularClient.account.address,
      assets,
      surplusAssets: 0n,
      giveAssets: assets + protocolAssets + rebalanceAssets,
      value,
    }]);
    const tunerData = encodeAbiParameters(TEST_TUNE_DATA_ABI, [{
      assets,
      protocolAssets,
      rebalanceAssets,
    }]);

    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        regularClient.account.address, // account
        mintAssets, // assets
      ],
    });
    await regularClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'approve',
      args: [
        pool.address, // spender
        depositAssets, // value
      ],
    });
    await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'deposit',
      args: [
        depositAssets, // assets
        regularClient.account.address, // receiver
      ],
    });
    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        taker.address, // taker
        tuner.address, // tuner
      ],
    });

    // First
    await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'take',
      args: [
        assets, // assets
        taker.address, // taker
        firstTakerData, // takerData
        tunerData, // tunerData
      ],
      value,
    });

    expect(await publicClient.readContract({
      abi: taker.abi,
      address: taker.address,
      functionName: 'taken',
      args: [id],
    })).equal(false);

    // Second
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

    expect(await publicClient.readContract({
      abi: taker.abi,
      address: taker.address,
      functionName: 'taken',
      args: [id],
    })).equal(true);

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`FlexPool.take deposit second gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: pool.abi,
      logs: receipt.logs,
      eventName: 'Take',
      args: {
        taker: taker.address,
        assets,
        protocolAssets,
        rebalanceAssets,
      },
    });
    expect(logs.length).equal(1);

    const takerAssets = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        taker.address, // account
      ],
    });
    expect(takerAssets).equal(assets * 2n);

    const takerNative = await publicClient.getBalance({ address: taker.address });
    expect(takerNative).equal(value * 2n);

    const poolAssets = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        pool.address, // account
      ],
    });
    expect(poolAssets).equal(depositAssets - assets * 2n);

    const poolCurrentAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'currentAssets',
      args: [],
    });
    expect(poolCurrentAssets).equal(depositAssets - assets * 2n);

    const poolEquilibriumAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'equilibriumAssets',
      args: [],
    });
    expect(poolEquilibriumAssets).equal(-(assets + protocolAssets + rebalanceAssets) * 2n);

    const poolAvailableAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'availableAssets',
      args: [],
    });
    expect(poolAvailableAssets).equal(depositAssets - (assets + rebalanceAssets) * 2n);

    const poolRebalanceAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'rebalanceAssets',
      args: [],
    });
    expect(poolRebalanceAssets).equal(rebalanceAssets * 2n);

    const depositorAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'previewRedeem',
      args: [
        await publicClient.readContract({
          abi: pool.abi,
          address: pool.address,
          functionName: 'balanceOf',
          args: [
            regularClient.account.address, // account
          ],
        }), // shares
      ],
    });
    expect(depositorAssets).equal(depositAssets + protocolAssets * 2n - 1n); // Gets all protocol assets as the only depositor
  });

  it('Should perform second take of deposit with surplus', async function () {
    const { asset, pool, taker, tuner, publicClient, regularClient, ownerClient } = await loadFixture(deployFixture);

    const firstId = '0x0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d';
    const id = '0x1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d';
    const depositAssets = 5_000_000_000n;
    const mintAssets = depositAssets + 3_000_000_000n;
    const value = 123_456n;
    const assets = 133_701_337n;
    const protocolAssets = 3_302n;
    const firstRebalanceAssets = 137_137n;
    const rebalanceAssets = -13_337n;
    const firstTakerData = encodeAbiParameters(TEST_TAKE_DATA_ABI, [{
      id: firstId,
      caller: regularClient.account.address,
      assets,
      surplusAssets: 0n,
      giveAssets: assets + protocolAssets + firstRebalanceAssets,
      value,
    }]);
    const takerData = encodeAbiParameters(TEST_TAKE_DATA_ABI, [{
      id,
      caller: regularClient.account.address,
      assets,
      surplusAssets: -rebalanceAssets,
      giveAssets: assets + protocolAssets,
      value,
    }]);
    const firstTunerData = encodeAbiParameters(TEST_TUNE_DATA_ABI, [{
      assets,
      protocolAssets,
      rebalanceAssets: firstRebalanceAssets,
    }]);
    const tunerData = encodeAbiParameters(TEST_TUNE_DATA_ABI, [{
      assets,
      protocolAssets,
      rebalanceAssets,
    }]);

    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        regularClient.account.address, // account
        mintAssets, // assets
      ],
    });
    await regularClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'approve',
      args: [
        pool.address, // spender
        depositAssets, // value
      ],
    });
    await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'deposit',
      args: [
        depositAssets, // assets
        regularClient.account.address, // receiver
      ],
    });
    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        taker.address, // taker
        tuner.address, // tuner
      ],
    });

    // First
    await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'take',
      args: [
        assets, // assets
        taker.address, // taker
        firstTakerData, // takerData
        firstTunerData, // tunerData
      ],
      value,
    });

    expect(await publicClient.readContract({
      abi: taker.abi,
      address: taker.address,
      functionName: 'taken',
      args: [id],
    })).equal(false);

    // Second
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

    expect(await publicClient.readContract({
      abi: taker.abi,
      address: taker.address,
      functionName: 'taken',
      args: [id],
    })).equal(true);

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`FlexPool.take deposit second surplus gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: pool.abi,
      logs: receipt.logs,
      eventName: 'Take',
      args: {
        taker: taker.address,
        assets,
        protocolAssets,
        rebalanceAssets,
      },
    });
    expect(logs.length).equal(1);

    const takerAssets = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        taker.address, // account
      ],
    });
    expect(takerAssets).equal(assets * 2n + -rebalanceAssets);

    const takerNative = await publicClient.getBalance({ address: taker.address });
    expect(takerNative).equal(value * 2n);

    const poolAssets = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        pool.address, // account
      ],
    });
    expect(poolAssets).equal(depositAssets - assets * 2n - -rebalanceAssets);

    const poolCurrentAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'currentAssets',
      args: [],
    });
    expect(poolCurrentAssets).equal(depositAssets - assets * 2n - -rebalanceAssets);

    const poolEquilibriumAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'equilibriumAssets',
      args: [],
    });
    expect(poolEquilibriumAssets).equal(-(assets + protocolAssets) * 2n - firstRebalanceAssets);

    const poolAvailableAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'availableAssets',
      args: [],
    });
    expect(poolAvailableAssets).equal(depositAssets - assets * 2n - firstRebalanceAssets);

    const poolRebalanceAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'rebalanceAssets',
      args: [],
    });
    expect(poolRebalanceAssets).equal(firstRebalanceAssets - -rebalanceAssets);

    const depositorAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'previewRedeem',
      args: [
        await publicClient.readContract({
          abi: pool.abi,
          address: pool.address,
          functionName: 'balanceOf',
          args: [
            regularClient.account.address, // account
          ],
        }), // shares
      ],
    });
    expect(depositorAssets).equal(depositAssets + protocolAssets * 2n - 1n); // Gets all protocol assets as the only depositor
  });

  it('Should equalize by transfer after two takes of deposit one with surplus', async function () {
    const { asset, pool, taker, tuner, publicClient, regularClient, ownerClient } = await loadFixture(deployFixture);

    const firstId = '0x0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d';
    const id = '0x1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d';
    const depositAssets = 5_000_000_000n;
    const mintAssets = depositAssets + 3_000_000_000n;
    const value = 123_456n;
    const assets = 133_701_337n;
    const protocolAssets = 3_302n;
    const firstRebalanceAssets = 137_137n;
    const rebalanceAssets = -13_337n;
    const firstGiveAssets = assets + protocolAssets + firstRebalanceAssets;
    const giveAssets = assets + protocolAssets;
    const firstTakerData = encodeAbiParameters(TEST_TAKE_DATA_ABI, [{
      id: firstId,
      caller: regularClient.account.address,
      assets,
      surplusAssets: 0n,
      giveAssets: firstGiveAssets,
      value,
    }]);
    const takerData = encodeAbiParameters(TEST_TAKE_DATA_ABI, [{
      id,
      caller: regularClient.account.address,
      assets,
      surplusAssets: -rebalanceAssets,
      giveAssets,
      value,
    }]);
    const firstTunerData = encodeAbiParameters(TEST_TUNE_DATA_ABI, [{
      assets,
      protocolAssets,
      rebalanceAssets: firstRebalanceAssets,
    }]);
    const tunerData = encodeAbiParameters(TEST_TUNE_DATA_ABI, [{
      assets,
      protocolAssets,
      rebalanceAssets,
    }]);

    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        regularClient.account.address, // account
        mintAssets, // assets
      ],
    });
    await regularClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'approve',
      args: [
        pool.address, // spender
        depositAssets, // value
      ],
    });
    await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'deposit',
      args: [
        depositAssets, // assets
        regularClient.account.address, // receiver
      ],
    });
    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        taker.address, // taker
        tuner.address, // tuner
      ],
    });

    // First
    await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'take',
      args: [
        assets, // assets
        taker.address, // taker
        firstTakerData, // takerData
        firstTunerData, // tunerData
      ],
      value,
    });

    // Second
    await regularClient.writeContract({
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

    // Fulfill give expectations
    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        pool.address, // account
        firstGiveAssets + giveAssets, // assets
      ],
    });

    const poolAssets = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        pool.address, // account
      ],
    });
    expect(poolAssets).equal(depositAssets + firstRebalanceAssets - -rebalanceAssets + protocolAssets * 2n);

    const poolCurrentAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'currentAssets',
      args: [],
    });
    expect(poolCurrentAssets).equal(depositAssets + firstRebalanceAssets - -rebalanceAssets + protocolAssets * 2n);

    const poolEquilibriumAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'equilibriumAssets',
      args: [],
    });
    expect(poolEquilibriumAssets).equal(0n);

    const poolAvailableAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'availableAssets',
      args: [],
    });
    expect(poolAvailableAssets).equal(depositAssets + protocolAssets * 2n);

    const poolRebalanceAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'rebalanceAssets',
      args: [],
    });
    expect(poolRebalanceAssets).equal(firstRebalanceAssets - -rebalanceAssets);

    const depositorAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'previewRedeem',
      args: [
        await publicClient.readContract({
          abi: pool.abi,
          address: pool.address,
          functionName: 'balanceOf',
          args: [
            regularClient.account.address, // account
          ],
        }), // shares
      ],
    });
    expect(depositorAssets).equal(depositAssets + protocolAssets * 2n - 1n); // Gets all protocol assets as the only depositor
  });

  it('Should perform withdraw of available after take of deposit', async function () {
    const { asset, pool, taker, tuner, publicClient, regularClient, ownerClient } = await loadFixture(deployFixture);

    const id = '0x1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d';
    const depositAssets = 5_000_000_000n;
    const mintAssets = depositAssets + 3_000_000_000n;
    const value = 123_456n;
    const assets = 133_701_337n;
    const protocolAssets = 3_302n;
    const rebalanceAssets = 137_137n;
    const takerData = encodeAbiParameters(TEST_TAKE_DATA_ABI, [{
      id,
      caller: regularClient.account.address,
      assets,
      surplusAssets: 0n,
      giveAssets: assets + protocolAssets + rebalanceAssets,
      value,
    }]);
    const tunerData = encodeAbiParameters(TEST_TUNE_DATA_ABI, [{
      assets,
      protocolAssets,
      rebalanceAssets,
    }]);

    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        regularClient.account.address, // account
        mintAssets, // assets
      ],
    });
    await regularClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'approve',
      args: [
        pool.address, // spender
        depositAssets, // value
      ],
    });
    await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'deposit',
      args: [
        depositAssets, // assets
        regularClient.account.address, // receiver
      ],
    });
    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        taker.address, // taker
        tuner.address, // tuner
      ],
    });

    await regularClient.writeContract({
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

    await expect(
      regularClient.writeContract({
        abi: pool.abi,
        address: pool.address,
        functionName: 'withdraw',
        args: [
          depositAssets, // assets
          regularClient.account.address, // receiver
          regularClient.account.address, // owner
        ],
      }),
    ).rejectedWith(
      `ERC20InsufficientBalance("${checksumAddress(pool.address)}", ${depositAssets - assets}, ${depositAssets})`
    );

    const withdrawAvailableAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'clampAssetsToAvailable',
      args: [
        depositAssets, // assets
      ],
    });
    expect(withdrawAvailableAssets).equal(depositAssets - (assets + rebalanceAssets));

    const withdrawAvailableShares = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'previewWithdraw',
      args: [
        withdrawAvailableAssets, // assets
      ],
    });

    const hash = await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'withdrawAvailable',
      args: [
        depositAssets, // assets
        regularClient.account.address, // receiver
        regularClient.account.address, // owner
      ],
    });

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`FlexPool.withdrawAvailable gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: pool.abi,
      logs: receipt.logs,
      eventName: 'Withdraw',
      args: {
        sender: regularClient.account.address,
        receiver: regularClient.account.address,
        owner: regularClient.account.address,
        assets: withdrawAvailableAssets,
        shares: withdrawAvailableShares,
      },
    });
    expect(logs.length).equal(1);

    const poolAssets = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        pool.address, // account
      ],
    });
    expect(poolAssets).equal(depositAssets - assets - withdrawAvailableAssets);

    const poolCurrentAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'currentAssets',
      args: [],
    });
    expect(poolCurrentAssets).equal(depositAssets - assets - withdrawAvailableAssets);

    const poolEquilibriumAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'equilibriumAssets',
      args: [],
    });
    expect(poolEquilibriumAssets).equal(-(assets + protocolAssets + rebalanceAssets));

    const poolAvailableAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'availableAssets',
      args: [],
    });
    expect(poolAvailableAssets).equal(depositAssets - (assets + rebalanceAssets) - withdrawAvailableAssets);

    const poolRebalanceAssets = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'rebalanceAssets',
      args: [],
    });
    expect(poolRebalanceAssets).equal(rebalanceAssets);
  });
});
