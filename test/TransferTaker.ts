import { loadFixture, } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers';
import hre from 'hardhat';
import { expect } from 'chai';
import {
  checksumAddress,
  encodeAbiParameters,
  encodeEventTopics,
  getAbiItem,
  Hex,
  maxUint256,
  parseAbiParameters,
  parseEventLogs,
  zeroAddress,
} from 'viem';

const TRANSFER_TAKE_DATA_ABI = parseAbiParameters([
  'TransferTakeData',
  'struct TransferTakeData { uint256 giveAssets; uint256 takeNonce; bytes giveProof; }',
]);
const TEST_TUNE_DATA_ABI = parseAbiParameters([
  'TestTuneData',
  'struct TestTuneData { uint256 assets; uint256 protocolAssets; int256 rebalanceAssets; }',
]);

describe('TransferTaker', function () {
  async function deployFixture() {
    const publicClient = await hre.viem.getPublicClient();
    const [regularClient, ownerClient, anotherClient] = await hre.viem.getWalletClients();

    const giverAsset = await hre.viem.deployContract('TestToken', [
      'Test Token - Giver', // name
      'TTG', // symbol
      6, // decimals
    ]);

    const takerAsset = await hre.viem.deployContract('TestToken', [
      'Test Token - Taker', // name
      'TTT', // symbol
      9, // decimals
    ]);

    const takerPool = await hre.viem.deployContract('FlexPool', [
      takerAsset.address, // asset
      'Pool Test Token - Taker', // name
      'PTTT', // symbol
      18, // decimalsOffset
      ownerClient.account.address, // initialOwner
    ]);

    const giverPool = await hre.viem.deployContract('TestPool');
    await giverPool.write.setAsset([giverAsset.address]);

    const giver = await hre.viem.deployContract('TransferGiver', [
      giverPool.address, // pool
      zeroAddress, // controller
    ]);

    const verifier = await hre.viem.deployContract('TestVerifier');

    const taker = await hre.viem.deployContract('TransferTaker', [
      takerPool.address, // pool
      verifier.address, // verifier
      zeroAddress, // controller
      55_555n, // giveChain
      giver.address, // giveTransferGiver
      BigInt(
        await giverAsset.read.decimals() -
        await takerAsset.read.decimals()
      ), // giveDecimalsShift
    ]);

    const tuner = await hre.viem.deployContract('TestTuner');

    await ownerClient.writeContract({
      abi: takerPool.abi,
      address: takerPool.address,
      functionName: 'setTuner',
      args: [
        taker.address, // taker
        tuner.address, // tuner
      ],
    });

    return {
      publicClient,
      regularClient,
      ownerClient,
      anotherClient,
      giverPool,
      giverAsset,
      giver,
      takerPool,
      takerAsset,
      taker,
      verifier,
    };
  }

  it('Should have giver code', async function () {
    const { publicClient, giver } = await loadFixture(deployFixture);

    const code = await publicClient.getCode({ address: giver.address });
    expect(code?.length ?? 0).greaterThan(0);
    console.log(`Code: ${code}`);
  });

  it('Should have taker code', async function () {
    const { publicClient, taker } = await loadFixture(deployFixture);

    const code = await publicClient.getCode({ address: taker.address });
    expect(code?.length ?? 0).greaterThan(0);
    console.log(`Code: ${code}`);
  });

  it('Should give approved asset to pool', async function () {
    const { publicClient, regularClient, ownerClient, giver, giverAsset, giverPool } = await loadFixture(deployFixture);

    await ownerClient.writeContract({
      abi: giverAsset.abi,
      address: giverAsset.address,
      functionName: 'mint',
      args: [
        regularClient.account.address, // account
        1_234_567n, // assets
      ],
    });
    await regularClient.writeContract({
      abi: giverAsset.abi,
      address: giverAsset.address,
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
    console.log(`TransferGiver.give gas: ${receipt.gasUsed}`);

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
      abi: giverAsset.abi,
      address: giverAsset.address,
      functionName: 'balanceOf',
      args: [
        giverPool.address, // account
      ],
    });
    expect(poolBalance).equal(123_456n);
  });

  it('Should give hold asset to pool', async function () {
    const { publicClient, regularClient, ownerClient, giver, giverAsset, giverPool } = await loadFixture(deployFixture);

    await ownerClient.writeContract({
      abi: giverAsset.abi,
      address: giverAsset.address,
      functionName: 'mint',
      args: [
        regularClient.account.address, // account
        1_234_567n, // assets
      ],
    });
    await regularClient.writeContract({
      abi: giverAsset.abi,
      address: giverAsset.address,
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
    console.log(`TransferGiver.giveHold gas: ${receipt.gasUsed}`);

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
      abi: giverAsset.abi,
      address: giverAsset.address,
      functionName: 'balanceOf',
      args: [
        giverPool.address, // account
      ],
    });
    expect(poolBalance).equal(123_456n);
  });

  it('Should take pool asset using give proof', async function () {
    const {
      publicClient,
      regularClient,
      ownerClient,
      anotherClient,
      taker,
      takerAsset,
      takerPool,
      giver,
      verifier,
    } = await loadFixture(deployFixture);

    const giveAssets = 123_486n;
    const takeNonce = 0n;
    const takeAssets = 123_456_000n; // = (giveAssets - protocolAssets - rebalanceAssets) in +3 decimals
    const protocolAssets = 10_000n;
    const rebalanceAssets = 20_000n;
    const poolInitAssets = takeAssets * 5n;
    const takeReceiver = anotherClient.account.address;
    const giveProof = '0x0123456780abcdef';
    const takerData = encodeAbiParameters(TRANSFER_TAKE_DATA_ABI, [{
      giveAssets,
      takeNonce,
      giveProof,
    }]);
    const tunerData = encodeAbiParameters(TEST_TUNE_DATA_ABI, [{
      assets: takeAssets,
      protocolAssets,
      rebalanceAssets,
    }]);

    expect(await publicClient.readContract({
      abi: taker.abi,
      address: taker.address,
      functionName: 'taken',
      args: [
        takeReceiver, // receiver
        takeNonce, // nonce
      ],
    })).equal(false);

    await ownerClient.writeContract({
      abi: takerAsset.abi,
      address: takerAsset.address,
      functionName: 'mint',
      args: [
        takerPool.address, // account
        poolInitAssets, // assets
      ],
    });

    await expect(regularClient.writeContract({
      abi: takerPool.abi,
      address: takerPool.address,
      functionName: 'take',
      args: [
        takeAssets, // assets
        taker.address, // taker
        takerData, // takerData
        tunerData, // tunerData
      ],
    })).rejectedWith('InvalidEvent'); // Wrong "regular" client used instead of "another"

    await expect(anotherClient.writeContract({
      abi: takerPool.abi,
      address: takerPool.address,
      functionName: 'take',
      args: [
        takeAssets, // assets
        taker.address, // taker
        takerData, // takerData
        tunerData, // tunerData
      ],
    })).rejectedWith('InvalidEvent');

    const transferGiveTopics = encodeEventTopics({
      abi: giver.abi,
      eventName: 'TransferGive',
    }) as Hex[];
    const transferGiveData = encodeAbiParameters(
      getAbiItem({
        abi: giver.abi,
        name: 'TransferGive',
      }).inputs,
      [
        giveAssets, // assets
        31_337n, // takeChain
        takeReceiver, // takeReceiver
        takeNonce, // takeNonce
      ],
    );
    await ownerClient.writeContract({
      abi: verifier.abi,
      address: verifier.address,
      functionName: 'setEventVerified',
      args: [
        55_555n, // chain
        giver.address, // emitter
        transferGiveTopics, // topics
        transferGiveData, // data
        giveProof, // proof
        true, // verified
      ],
    });

    const hash = await anotherClient.writeContract({
      abi: takerPool.abi,
      address: takerPool.address,
      functionName: 'take',
      args: [
        takeAssets, // assets
        taker.address, // taker
        takerData, // takerData
        tunerData, // tunerData
      ],
    });

    expect(await publicClient.readContract({
      abi: taker.abi,
      address: taker.address,
      functionName: 'taken',
      args: [
        takeReceiver, // receiver
        takeNonce, // nonce
      ],
    })).equal(true);

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`Pool.take with TransferTaker.take gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: takerPool.abi,
      logs: receipt.logs,
      eventName: 'Take',
      args: {
        taker: taker.address,
        assets: takeAssets,
        protocolAssets,
        rebalanceAssets,
      },
    });
    expect(logs.length).equal(1);

    const receiverBalance = await publicClient.readContract({
      abi: takerAsset.abi,
      address: takerAsset.address,
      functionName: 'balanceOf',
      args: [
        takeReceiver, // account
      ],
    });
    expect(receiverBalance).equal(takeAssets);

    const poolBalance = await publicClient.readContract({
      abi: takerAsset.abi,
      address: takerAsset.address,
      functionName: 'balanceOf',
      args: [
        takerPool.address, // account
      ],
    });
    expect(poolBalance).equal(poolInitAssets - takeAssets);

    const poolRebalanceAssets = await publicClient.readContract({
      abi: takerPool.abi,
      address: takerPool.address,
      functionName: 'rebalanceAssets',
      args: [],
    });
    expect(poolRebalanceAssets).equal(rebalanceAssets);

    await expect(anotherClient.writeContract({
      abi: takerPool.abi,
      address: takerPool.address,
      functionName: 'take',
      args: [
        takeAssets, // assets
        taker.address, // taker
        takerData, // takerData
        tunerData, // tunerData
      ],
    })).rejectedWith(`AlreadyTaken("${checksumAddress(takeReceiver)}", ${takeNonce})`);
  });

  it('Should take pool asset using give proof second time', async function () {
    const {
      publicClient,
      regularClient,
      ownerClient,
      anotherClient,
      taker,
      takerAsset,
      takerPool,
      giver,
      verifier,
    } = await loadFixture(deployFixture);

    const giveAssets = 123_486n;
    const takeNonce = 0n;
    const takeNonce2 = takeNonce + 1n;
    const takeAssets = 123_456_000n; // = (giveAssets - protocolAssets - rebalanceAssets) in +3 decimals
    const protocolAssets = 10_000n;
    const rebalanceAssets = 20_000n;
    const poolInitAssets = takeAssets * 5n;
    const takeReceiver = anotherClient.account.address;
    const giveProof = '0x0123456780abcdef';
    const takerData = encodeAbiParameters(TRANSFER_TAKE_DATA_ABI, [{
      giveAssets,
      takeNonce,
      giveProof,
    }]);
    const takerData2 = encodeAbiParameters(TRANSFER_TAKE_DATA_ABI, [{
      giveAssets,
      takeNonce: takeNonce2,
      giveProof,
    }]);
    const tunerData = encodeAbiParameters(TEST_TUNE_DATA_ABI, [{
      assets: takeAssets,
      protocolAssets,
      rebalanceAssets,
    }]);

    expect(await publicClient.readContract({
      abi: taker.abi,
      address: taker.address,
      functionName: 'taken',
      args: [
        takeReceiver, // receiver
        takeNonce2, // nonce
      ],
    })).equal(false);

    await ownerClient.writeContract({
      abi: takerAsset.abi,
      address: takerAsset.address,
      functionName: 'mint',
      args: [
        takerPool.address, // account
        poolInitAssets, // assets
      ],
    });

    const transferGiveTopics = encodeEventTopics({
      abi: giver.abi,
      eventName: 'TransferGive',
    }) as Hex[];
    const transferGiveData = encodeAbiParameters(
      getAbiItem({
        abi: giver.abi,
        name: 'TransferGive',
      }).inputs,
      [
        giveAssets, // assets
        31_337n, // takeChain
        takeReceiver, // takeReceiver
        takeNonce, // takeNonce
      ],
    );
    await ownerClient.writeContract({
      abi: verifier.abi,
      address: verifier.address,
      functionName: 'setEventVerified',
      args: [
        55_555n, // chain
        giver.address, // emitter
        transferGiveTopics, // topics
        transferGiveData, // data
        giveProof, // proof
        true, // verified
      ],
    });

    await expect(regularClient.writeContract({
      abi: takerPool.abi,
      address: takerPool.address,
      functionName: 'take',
      args: [
        takeAssets, // assets
        taker.address, // taker
        takerData, // takerData
        tunerData, // tunerData
      ],
    })).rejectedWith('InvalidEvent'); // Wrong "regular" client used instead of "another"

    // First
    await anotherClient.writeContract({
      abi: takerPool.abi,
      address: takerPool.address,
      functionName: 'take',
      args: [
        takeAssets, // assets
        taker.address, // taker
        takerData, // takerData
        tunerData, // tunerData
      ],
    });

    expect(await publicClient.readContract({
      abi: taker.abi,
      address: taker.address,
      functionName: 'taken',
      args: [
        takeReceiver, // receiver
        takeNonce2, // nonce
      ],
    })).equal(false);

    const transferGiveData2 = encodeAbiParameters(
      getAbiItem({
        abi: giver.abi,
        name: 'TransferGive',
      }).inputs,
      [
        giveAssets, // assets
        31_337n, // takeChain
        takeReceiver, // takeReceiver
        takeNonce2, // takeNonce
      ],
    );
    await ownerClient.writeContract({
      abi: verifier.abi,
      address: verifier.address,
      functionName: 'setEventVerified',
      args: [
        55_555n, // chain
        giver.address, // emitter
        transferGiveTopics, // topics
        transferGiveData2, // data
        giveProof, // proof
        true, // verified
      ],
    });

    // Second
    const hash = await anotherClient.writeContract({
      abi: takerPool.abi,
      address: takerPool.address,
      functionName: 'take',
      args: [
        takeAssets, // assets
        taker.address, // taker
        takerData2, // takerData
        tunerData, // tunerData
      ],
    });

    expect(await publicClient.readContract({
      abi: taker.abi,
      address: taker.address,
      functionName: 'taken',
      args: [
        takeReceiver, // receiver
        takeNonce2, // nonce
      ],
    })).equal(true);

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`Pool.take with TransferTaker.take second gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: takerPool.abi,
      logs: receipt.logs,
      eventName: 'Take',
      args: {
        taker: taker.address,
        assets: takeAssets,
        protocolAssets,
        rebalanceAssets,
      },
    });
    expect(logs.length).equal(1);

    const receiverBalance = await publicClient.readContract({
      abi: takerAsset.abi,
      address: takerAsset.address,
      functionName: 'balanceOf',
      args: [
        takeReceiver, // account
      ],
    });
    expect(receiverBalance).equal(takeAssets * 2n);

    const poolBalance = await publicClient.readContract({
      abi: takerAsset.abi,
      address: takerAsset.address,
      functionName: 'balanceOf',
      args: [
        takerPool.address, // account
      ],
    });
    expect(poolBalance).equal(poolInitAssets - takeAssets * 2n);

    const poolRebalanceAssets = await publicClient.readContract({
      abi: takerPool.abi,
      address: takerPool.address,
      functionName: 'rebalanceAssets',
      args: [],
    });
    expect(poolRebalanceAssets).equal(rebalanceAssets * 2n);

    await expect(anotherClient.writeContract({
      abi: takerPool.abi,
      address: takerPool.address,
      functionName: 'take',
      args: [
        takeAssets, // assets
        taker.address, // taker
        takerData2, // takerData
        tunerData, // tunerData
      ],
    })).rejectedWith(`AlreadyTaken("${checksumAddress(takeReceiver)}", ${takeNonce2})`);
  });
});
