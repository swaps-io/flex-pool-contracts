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
      100n, // protocolFixed
      parseEther('3.5'), // protocolPercent
      200n, // rebalanceFixed
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
    ]);
    expect(protocolAssets).equal(100n); // 100 fixed
    expect(rebalanceAssets).equal(0n); // No fixed: applied when > 0
  });

  it('Should tune for assets at equilibrium', async function () {
    const { tuner } = await loadFixture(deployFixture);

    const [protocolAssets, rebalanceAssets] = await tuner.read.tune([
      123_456n, // assets
    ]);
    expect(protocolAssets).equal(4_421n); // 4_320.96 ceil + 100 fixed
    expect(rebalanceAssets).equal(5_386n); // eq 0 -> -123_456, 5_185.152 ceil + 200 fixed
  });

  it('Should tune for assets at far negative equilibrium', async function () {
    const { tuner, pool } = await loadFixture(deployFixture);

    await pool.write.setEquilibriumAssets([-400_000n]);

    const [protocolAssets, rebalanceAssets] = await tuner.read.tune([
      123_456n, // assets
    ]);
    expect(protocolAssets).equal(4_421n); // 4_320.96 ceil + 100 fixed
    expect(rebalanceAssets).equal(5_386n); // eq -400_000 -> -523_456, 5_185.152 ceil + 200 fixed
  });

  it('Should tune for assets at far positive equilibrium and empty rebalance assets', async function () {
    const { tuner, pool } = await loadFixture(deployFixture);

    await pool.write.setEquilibriumAssets([400_000n]);

    const [protocolAssets, rebalanceAssets] = await tuner.read.tune([
      123_456n, // assets
    ]);
    expect(protocolAssets).equal(4_421n); // 4_320.96 ceil + 100 fixed
    expect(rebalanceAssets).equal(0n); // eq +400_000 -> +276_544, yet budget is empty
  });

  it('Should tune for assets at far positive equilibrium', async function () {
    const { tuner, pool } = await loadFixture(deployFixture);

    await pool.write.setEquilibriumAssets([400_000n]);
    await pool.write.setRebalanceAssets([10_000n]);

    const [protocolAssets, rebalanceAssets] = await tuner.read.tune([
      123_456n, // assets
    ]);
    expect(protocolAssets).equal(4_421n); // 4_320.96 ceil + 100 fixed
    expect(rebalanceAssets).equal(-3_086n); // eq +400_000 -> +276_544, -3_086.4 floor
  });

  it('Should tune for assets at edge positive equilibrium', async function () {
    const { tuner, pool } = await loadFixture(deployFixture);

    await pool.write.setEquilibriumAssets([123_456n]);
    await pool.write.setRebalanceAssets([10_000n]);

    const [protocolAssets, rebalanceAssets] = await tuner.read.tune([
      123_456n, // assets
    ]);
    expect(protocolAssets).equal(4_421n); // 4_320.96 ceil + 100 fixed
    expect(rebalanceAssets).equal(-10_000n); // eq +123_456 -> 0, entire budget
  });

  it('Should tune for assets crossing positive-negative border of equilibrium', async function () {
    const { tuner, pool } = await loadFixture(deployFixture);

    await pool.write.setEquilibriumAssets([88_000n]);
    await pool.write.setRebalanceAssets([10_000n]);

    const [protocolAssets, rebalanceAssets] = await tuner.read.tune([
      123_456n, // assets
    ]);
    expect(protocolAssets).equal(4_421n); // 4_320.96 ceil + 100 fixed
    expect(rebalanceAssets).equal(-8_310n); // eq +88_000 -> 0 -> -35_456, entire budget, 1489.152 ceil + 200 fixed
  });
});
