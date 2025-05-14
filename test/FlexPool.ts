import { loadFixture, } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers';
import hre from 'hardhat';
import { expect } from 'chai';

describe('FlexPool', function () {
  async function deployFixture() {
    const publicClient = await hre.viem.getPublicClient();
    const [walletClient] = await hre.viem.getWalletClients();

    const asset = await hre.viem.deployContract('TestToken', [
      'Test Token', // name
      'TT', // symbol
      18, // decimals
    ]);

    const pool = await hre.viem.deployContract('FlexPool', [
      asset.address, // asset
      'Pool Test Token', // name
      'PTT', // symbol
    ]);

    return {
      publicClient,
      walletClient,
      pool,
    };
  }

  it('Should have code', async function () {
    const { publicClient, pool } = await loadFixture(deployFixture);

    const code = await publicClient.getCode({ address: pool.address });
    expect(code?.length ?? 0).greaterThan(0);
    console.log(`Code: ${code}`);
  });
});
