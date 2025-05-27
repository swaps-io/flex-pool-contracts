import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import hre from 'hardhat';
import { expect } from 'chai';
import { parseEther } from 'viem';

describe('LinearTuner', function () {
  async function deployFixture() {
    const publicClient = await hre.viem.getPublicClient();

    const pool = await hre.viem.deployContract('TestPool');

    const tuner = await hre.viem.deployContract('LinearTuner', [
      pool.address, // pool
      parseEther('3.5'), // protocolPercent
      parseEther('4.2'), // rebalancePercent
    ]);

    return {
      publicClient,
      pool,
      tuner,
    };
  }

  it('Should have code', async function () {
    const { publicClient, tuner } = await loadFixture(deployFixture);

    const code = await publicClient.getCode({ address: tuner.address });
    expect(code?.length ?? 0).greaterThan(0);
    console.log(`Code: ${code}`);
  });

  it('Should tune for zero assets', async function () {
    const { tuner } = await loadFixture(deployFixture);

    const [protocolAssets, rebalanceAssets] = await tuner.read.tune([
      0n, // assets
      '0x', // data
    ]);
    expect(protocolAssets).equal(0n);
    expect(rebalanceAssets).equal(0n);
  });

  it('Should tune for assets at equilibrium', async function () {
    const { tuner } = await loadFixture(deployFixture);

    const [protocolAssets, rebalanceAssets] = await tuner.read.tune([
      123_456n, // assets
      '0x', // data
    ]);
    expect(protocolAssets).equal(4_321n); // 4_320.96 ceil
    expect(rebalanceAssets).equal(5_186n); // eq 0 -> -123_456, 5_185.152 ceil
  });

  it('Should tune for assets at far negative equilibrium', async function () {
    const { tuner, pool } = await loadFixture(deployFixture);

    await pool.write.setEquilibriumAssets([-400_000n]);

    const [protocolAssets, rebalanceAssets] = await tuner.read.tune([
      123_456n, // assets
      '0x', // data
    ]);
    expect(protocolAssets).equal(4_321n); // 4_320.96 ceil
    expect(rebalanceAssets).equal(5_186n); // eq -400_000 -> -523_456, 5_185.152 ceil
  });

  it('Should tune for assets at far positive equilibrium and empty rebalance reserve', async function () {
    const { tuner, pool } = await loadFixture(deployFixture);

    await pool.write.setEquilibriumAssets([400_000n]);

    const [protocolAssets, rebalanceAssets] = await tuner.read.tune([
      123_456n, // assets
      '0x', // data
    ]);
    expect(protocolAssets).equal(4_321n); // 4_320.96 ceil
    expect(rebalanceAssets).equal(0n); // eq +400_000 -> +276_544, yet rewards empty
  });

  it('Should tune for assets at far positive equilibrium', async function () {
    const { tuner, pool } = await loadFixture(deployFixture);

    await pool.write.setEquilibriumAssets([400_000n]);
    await pool.write.setRebalanceReserveAssets([10_000n]);

    const [protocolAssets, rebalanceAssets] = await tuner.read.tune([
      123_456n, // assets
      '0x', // data
    ]);
    expect(protocolAssets).equal(4_321n); // 4_320.96 ceil
    expect(rebalanceAssets).equal(-3_086n); // eq +400_000 -> +276_544, -3_086.4 floor
  });

  it('Should tune for assets at edge positive equilibrium', async function () {
    const { tuner, pool } = await loadFixture(deployFixture);

    await pool.write.setEquilibriumAssets([123_456n]);
    await pool.write.setRebalanceReserveAssets([10_000n]);

    const [protocolAssets, rebalanceAssets] = await tuner.read.tune([
      123_456n, // assets
      '0x', // data
    ]);
    expect(protocolAssets).equal(4_321n); // 4_320.96 ceil
    expect(rebalanceAssets).equal(-10_000n); // eq +123_456 -> 0, all rewards
  });

  it('Should tune for assets crossing positive-negative border of equilibrium', async function () {
    const { tuner, pool } = await loadFixture(deployFixture);

    await pool.write.setEquilibriumAssets([88_000n]);
    await pool.write.setRebalanceReserveAssets([10_000n]);

    const [protocolAssets, rebalanceAssets] = await tuner.read.tune([
      123_456n, // assets
      '0x', // data
    ]);
    expect(protocolAssets).equal(4_321n); // 4_320.96 ceil
    expect(rebalanceAssets).equal(-8_510n); // eq +88_000 -> 0 -> -35_456, all rewards, 1489.152 ceil
  });
});
