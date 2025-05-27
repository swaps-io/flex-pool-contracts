import { loadFixture, } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers';
import hre from 'hardhat';
import { expect } from 'chai';
import { encodeAbiParameters, getAbiItem, keccak256, maxUint256, parseAbiParameters, parseEventLogs, toEventSelector, zeroAddress } from 'viem';

const TRANSFER_GIVE_HASH_DATA_ABI = parseAbiParameters([
  'uint256 giveAssets, uint256 giveBlock, uint256 takeChain, address takeReceiver',
]);
const TRANSFER_TAKE_DATA_ABI = parseAbiParameters([
  'TransferTakeData',
  'struct TransferTakeData { uint256 giveAssets; uint256 giveBlock; address takeReceiver; bytes giveProof; }',
]);
const TEST_TUNE_DATA_ABI = parseAbiParameters([
  'TestTuneData',
  'struct TestTuneData { uint256 assets; uint256 protocolAssets; int256 rebalanceAssets; }',
]);

describe('TransferTaker', function () {
  async function deployFixture() {
    const publicClient = await hre.viem.getPublicClient();
    const [regularClient, ownerClient] = await hre.viem.getWalletClients();

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

    const pool = await hre.viem.deployContract('FlexPool', [
      takerAsset.address, // asset
      'Pool Test Token - Taker', // name
      'PTTT', // symbol
      18, // decimalsOffset
      ownerClient.account.address, // initialOwner
    ]);

    const giver = await hre.viem.deployContract('TransferGiver', [
      giverAsset.address, // asset
      pool.address, // pool
      zeroAddress, // controller
    ]);

    const verifier = await hre.viem.deployContract('TestVerifier');

    const taker = await hre.viem.deployContract('TransferTaker', [
      takerAsset.address, // asset
      55_555n, // giveChain
      giver.address, // giveTransferGiver
      BigInt(
        await giverAsset.read.decimals() -
        await takerAsset.read.decimals()
      ), // giveDecimalsShift
      verifier.address, // verifier
      zeroAddress, // controller
    ]);

    const tuner = await hre.viem.deployContract('TestTuner');

    await ownerClient.writeContract({
      abi: pool.abi,
      address: pool.address,
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
      pool,
      giverAsset,
      giver,
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
    const { publicClient, regularClient, ownerClient, giver, giverAsset, pool } = await loadFixture(deployFixture);

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
      ],
    });

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`TransferGiver.give gas: ${receipt.gasUsed}`);

    const giveHash = keccak256(encodeAbiParameters(TRANSFER_GIVE_HASH_DATA_ABI, [
      123_456n, // giveAssets
      receipt.blockNumber, // giveBlock
      31_337n, // takeChain
      '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', // takeReceiver
    ]));

    const logs = parseEventLogs({
      abi: giver.abi,
      logs: receipt.logs,
      eventName: 'TransferGive',
      args: {
        giveHash,
      },
    });
    expect(logs.length).equal(1);

    const poolBalance = await publicClient.readContract({
      abi: giverAsset.abi,
      address: giverAsset.address,
      functionName: 'balanceOf',
      args: [
        pool.address, // account
      ],
    });
    expect(poolBalance).equal(123_456n);
  });

  it('Should give hold asset to pool', async function () {
    const { publicClient, regularClient, ownerClient, giver, giverAsset, pool } = await loadFixture(deployFixture);

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
      ],
    });

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`TransferGiver.giveHold gas: ${receipt.gasUsed}`);

    const giveHash = keccak256(encodeAbiParameters(TRANSFER_GIVE_HASH_DATA_ABI, [
      123_456n, // giveAssets
      receipt.blockNumber, // giveBlock
      31_337n, // takeChain
      '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', // takeReceiver
    ]));

    const logs = parseEventLogs({
      abi: giver.abi,
      logs: receipt.logs,
      eventName: 'TransferGive',
      args: {
        giveHash,
      },
    });
    expect(logs.length).equal(1);

    const poolBalance = await publicClient.readContract({
      abi: giverAsset.abi,
      address: giverAsset.address,
      functionName: 'balanceOf',
      args: [
        pool.address, // account
      ],
    });
    expect(poolBalance).equal(123_456n);
  });

  it('Should take pool asset using give proof', async function () {
    const { publicClient, regularClient, ownerClient, taker, takerAsset, pool, giver, verifier } = await loadFixture(deployFixture);

    const giveAssets = 123_486n;
    const giveBlock = 111_111n;
    const takeAssets = 123_456_000n; // = (giveAssets - protocolAssets - rebalanceAssets) in +3 decimals
    const protocolAssets = 10_000n;
    const rebalanceAssets = 20_000n;
    const poolInitAssets = takeAssets * 2n;
    const takeReceiver = '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef';
    const giveHash = keccak256(encodeAbiParameters(TRANSFER_GIVE_HASH_DATA_ABI, [
      giveAssets, // giveAssets
      giveBlock, // giveBlock
      31_337n, // takeChain
      takeReceiver, // takeReceiver
    ]));
    const giveProof = '0x0123456780abcdef';
    const takerData = encodeAbiParameters(TRANSFER_TAKE_DATA_ABI, [{
      giveAssets,
      giveBlock,
      takeReceiver,
      giveProof,
    }]);
    const tunerData = encodeAbiParameters(TEST_TUNE_DATA_ABI, [{
      assets: takeAssets,
      protocolAssets,
      rebalanceAssets,
    }]);

    expect(await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'taken',
      args: [
        giveHash, // id
      ],
    })).equal(false);

    await ownerClient.writeContract({
      abi: takerAsset.abi,
      address: takerAsset.address,
      functionName: 'mint',
      args: [
        pool.address, // account
        poolInitAssets, // assets
      ],
    });

    await expect(regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'take',
      args: [
        takeAssets, // assets
        taker.address, // taker
        takerData, // takerData
        tunerData, // tunerData
      ],
    })).rejectedWith('InvalidEvent');

    await ownerClient.writeContract({
      abi: verifier.abi,
      address: verifier.address,
      functionName: 'setEventVerified',
      args: [
        55_555n, // chain
        giver.address, // emitter
        [
          toEventSelector(getAbiItem({
            abi: giver.abi,
            name: 'TransferGive',
          })),
          giveHash,
        ], // topics
        '0x', // data
        giveProof, // proof
        true, // verified
      ],
    });

    const hash = await regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'take',
      args: [
        takeAssets, // assets
        taker.address, // taker
        takerData, // takerData
        tunerData, // tunerData
      ],
    });

    expect(await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'taken',
      args: [
        giveHash, // id
      ],
    })).equal(true);

    const receipt = await publicClient.getTransactionReceipt({ hash });
    console.log(`Pool.take with TransferTaker.take gas: ${receipt.gasUsed}`);

    const logs = parseEventLogs({
      abi: pool.abi,
      logs: receipt.logs,
      eventName: 'Take',
      args: {
        id: giveHash,
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
        pool.address, // account
      ],
    });
    expect(poolBalance).equal(poolInitAssets - takeAssets);

    const poolRebalanceReserve = await publicClient.readContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'rebalanceReserveAssets',
      args: [],
    });
    expect(poolRebalanceReserve).equal(rebalanceAssets);

    await expect(regularClient.writeContract({
      abi: pool.abi,
      address: pool.address,
      functionName: 'take',
      args: [
        takeAssets, // assets
        taker.address, // taker
        takerData, // takerData
        tunerData, // tunerData
      ],
    })).rejectedWith(`AlreadyTaken("${giveHash}")`);
  });
});
