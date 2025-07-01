import { loadFixture, } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers';
import hre from 'hardhat';
import { expect } from 'chai';
import { maxUint256, parseEventLogs, zeroAddress } from 'viem';

describe('TransferReliefGiver', function () {
  async function deployFixture() {
    const publicClient = await hre.viem.getPublicClient();
    const [regularClient, ownerClient, anotherClient] = await hre.viem.getWalletClients();

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
      ownerClient.account.address, // controller
    ]);

    const tuner = await hre.viem.deployContract('TestTuner');

    const giver = await hre.viem.deployContract('TransferReliefGiver', [
      pool.address, // pool
      zeroAddress, // controller
      tuner.address, // tuner
    ]);

    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        giver.address, // taker (2-in-1)
        tuner.address, // tuner
      ],
    });

    return {
      publicClient,
      regularClient,
      ownerClient,
      anotherClient,
      giver,
      tuner,
      asset,
      pool,
    };
  }

  it('Should have relief giver code', async function () {
    const { publicClient, giver } = await loadFixture(deployFixture);

    const code = await publicClient.getCode({ address: giver.address });
    expect(code?.length ?? 0).greaterThan(0);
    console.log(`Code: ${code}`);
  });

  it('Should give approved asset to pool', async function () {
    const { publicClient, regularClient, ownerClient, giver, asset, pool } = await loadFixture(deployFixture);

    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        regularClient.account.address, // account
        1_234_567n, // assets
      ],
    });
    await regularClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'approve',
      args: [
        giver.address, // spender
        maxUint256, // value
      ],
    });

    const hash = await regularClient.writeContract({
      abi: giver.abi,
      address: giver.address,
      functionName: 'give',
      args: [
        123_456n, // assets
        31_337n, // takeChain
        '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', // takeReceiver
        0n, // takeNonce
      ],
    });

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`TransferReliefGiver.give gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: giver.abi,
      logs: receipt.logs,
      eventName: 'TransferGive',
      args: {
        assets: 123_456n,
        takeChain: 31_337n,
        takeReceiver: '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
        takeNonce: 0n,
      },
    });
    expect(logs.length).equal(1);

    const poolBalance = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        pool.address, // account
      ],
    });
    expect(poolBalance).equal(123_456n);
  });

  it('Should give hold asset to pool', async function () {
    const { publicClient, regularClient, ownerClient, giver, asset, pool } = await loadFixture(deployFixture);

    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        regularClient.account.address, // account
        1_234_567n, // assets
      ],
    });
    await regularClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'transfer',
      args: [
        giver.address, // to
        123_456n, // value
      ],
    });

    const hash = await regularClient.writeContract({
      abi: giver.abi,
      address: giver.address,
      functionName: 'giveHold',
      args: [
        123_456n, // assets
        31_337n, // takeChain
        '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', // takeReceiver
        0n, // takeNonce
      ],
    });

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`TransferReliefGiver.giveHold gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: giver.abi,
      logs: receipt.logs,
      eventName: 'TransferGive',
      args: {
        assets: 123_456n,
        takeChain: 31_337n,
        takeReceiver: '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
        takeNonce: 0n,
      },
    });
    expect(logs.length).equal(1);

    const poolBalance = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        pool.address, // account
      ],
    });
    expect(poolBalance).equal(123_456n);
  });

  // Relief

  it('Should give asset to pool with relief attempt', async function () {
    const { publicClient, regularClient, ownerClient, giver, asset, pool, tuner } = await loadFixture(deployFixture);

    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        regularClient.account.address, // account
        1_234_567n, // assets
      ],
    });
    await regularClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'approve',
      args: [
        giver.address, // spender
        maxUint256, // value
      ],
    });

    // Top up rebalance budget

    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        pool.address, // account
        10_000n, // assets
      ],
    });

    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        ownerClient.account.address, // taker
        tuner.address, // tuner
      ],
    });
    await ownerClient.writeContract({
      abi: tuner.abi,
      address: tuner.address,
      functionName: 'setRebalanceAssets',
      args: [
        10_000n, // assets
      ],
    });

    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'take',
      args: [
        0n, // assets
      ],
    });

    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        ownerClient.account.address, // taker
        zeroAddress, // tuner
      ],
    });
    await ownerClient.writeContract({
      abi: tuner.abi,
      address: tuner.address,
      functionName: 'setRebalanceAssets',
      args: [
        0n, // assets
      ],
    });

    // ---

    const hash = await regularClient.writeContract({
      abi: giver.abi,
      address: giver.address,
      functionName: 'give',
      args: [
        123_456n, // assets
        31_337n, // takeChain
        '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', // takeReceiver
        0n, // takeNonce
      ],
    });

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`TransferReliefGiver.give relief attempt gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: giver.abi,
      logs: receipt.logs,
      eventName: 'TransferGive',
      args: {
        assets: 123_456n,
        takeChain: 31_337n,
        takeReceiver: '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
        takeNonce: 0n,
      },
    });
    expect(logs.length).equal(1);

    const poolBalance = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        pool.address, // account
      ],
    });
    expect(poolBalance).equal(123_456n + 10_000n);
  });

  it('Should give asset to pool with relief', async function () {
    const { publicClient, regularClient, ownerClient, giver, asset, pool, tuner } = await loadFixture(deployFixture);

    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        regularClient.account.address, // account
        1_234_567n, // assets
      ],
    });
    await regularClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'approve',
      args: [
        giver.address, // spender
        maxUint256, // value
      ],
    });

    // Top up rebalance budget

    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        pool.address, // account
        25_000n, // assets
      ],
    });

    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        ownerClient.account.address, // taker
        tuner.address, // tuner
      ],
    });
    await ownerClient.writeContract({
      abi: tuner.abi,
      address: tuner.address,
      functionName: 'setRebalanceAssets',
      args: [
        25_000n, // assets
      ],
    });

    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'take',
      args: [
        0n, // assets
      ],
    });

    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        ownerClient.account.address, // taker
        zeroAddress, // tuner
      ],
    });
    await ownerClient.writeContract({
      abi: tuner.abi,
      address: tuner.address,
      functionName: 'setRebalanceAssets',
      args: [
        0n, // assets
      ],
    });

    // Create equilibrium deficiency

    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'mint',
      args: [
        ownerClient.account.address, // account
        100_000n, // assets
      ],
    });
    await ownerClient.writeContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'approve',
      args: [
        pool.address, // spender
        100_000n, // value
      ],
    });
    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'deposit',
      args: [
        100_000n, // assets
        ownerClient.account.address, // receiver
      ],
    });

    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        ownerClient.account.address, // taker
        tuner.address, // tuner
      ],
    });
    await ownerClient.writeContract({
      abi: tuner.abi,
      address: tuner.address,
      functionName: 'setExpectedAssets',
      args: [
        100_000n // assets
      ],
    });

    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'take',
      args: [
        100_000n, // assets
      ],
    });

    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'setTuner',
      args: [
        ownerClient.account.address, // taker
        zeroAddress, // tuner
      ],
    });
    await ownerClient.writeContract({
      abi: tuner.abi,
      address: tuner.address,
      functionName: 'setExpectedAssets',
      args: [
        0n // assets
      ],
    });

    {
      const equilibrium = await publicClient.readContract({
        abi: pool.abi,
        address: pool.address,
        functionName: 'equilibriumAssets',
        args: [],
      });
      expect(equilibrium).equal(-100_000n);
    }

    // ---

    await ownerClient.writeContract({
      abi: tuner.abi,
      address: tuner.address,
      functionName: 'setExpectedExtraReliefAssets',
      args: [
        100_000n, // assets
      ],
    });
    await ownerClient.writeContract({
      abi: tuner.abi,
      address: tuner.address,
      functionName: 'setProtocolAssets',
      args: [
        5_000n, // assets
      ],
    });
    await ownerClient.writeContract({
      abi: tuner.abi,
      address: tuner.address,
      functionName: 'setRebalanceAssets',
      args: [
        -13_000n, // assets
      ],
    });

    const hash = await regularClient.writeContract({
      abi: giver.abi,
      address: giver.address,
      functionName: 'give',
      args: [
        123_456n, // assets
        31_337n, // takeChain
        '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', // takeReceiver
        0n, // takeNonce
      ],
    });

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`TransferReliefGiver.give relief gas: ${receipt.gasUsed}`);

    {
      const logs = parseEventLogs({
        abi: giver.abi,
        logs: receipt.logs,
        eventName: 'TransferGive',
        args: {
          assets: 123_456n,
          takeChain: 31_337n,
          takeReceiver: '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
          takeNonce: 0n,
        },
      });
      expect(logs.length).equal(1);
    }
    {
      const logs = parseEventLogs({
        abi: asset.abi,
        logs: receipt.logs,
        eventName: 'Transfer',
        args: {
          from: giver.address,
          to: pool.address,
          value: 5_000n,
        },
      });
      expect(logs.length).equal(1);
    }
    {
      const logs = parseEventLogs({
        abi: asset.abi,
        logs: receipt.logs,
        eventName: 'Transfer',
        args: {
          from: giver.address,
          to: regularClient.account.address,
          value: 13_000n - 5_000n,
        },
      });
      expect(logs.length).equal(1);
    }

    const poolBalance = await publicClient.readContract({
      abi: asset.abi,
      address: asset.address,
      functionName: 'balanceOf',
      args: [
        pool.address, // account
      ],
    });
    expect(poolBalance).equal(123_456n + 25_000n + 5_000n - 13_000n);
  });
});
