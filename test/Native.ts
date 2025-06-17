import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import hre from 'hardhat';
import { expect } from 'chai';
import { parseEventLogs } from 'viem';

describe('Native', function () {
  async function deployFixture() {
    const publicClient = await hre.viem.getPublicClient();
    const [walletClient] = await hre.viem.getWalletClients();

    const test = await hre.viem.deployContract('TestNative');

    return {
      publicClient,
      walletClient,
      test,
    };
  }

  it('Should test native', async function () {
    const { publicClient, walletClient, test } = await loadFixture(deployFixture);

    await walletClient.sendTransaction({
      to: test.address,
      value: 100_000n,
    });

    {
      const hash = await test.write.testValueBalance({ value: 42_000n });

      const receipt = await publicClient.getTransactionReceipt({ hash });
      const logs = parseEventLogs({
        abi: test.abi,
        logs: receipt.logs,
        eventName: 'TestResult',
      });
      expect(logs.length).equal(1);
      expect(logs[0].args.value).equal(100_000n);
    }

    {
      const hash = await test.write.testValueAccess();

      const receipt = await publicClient.getTransactionReceipt({ hash });
      const logs = parseEventLogs({
        abi: test.abi,
        logs: receipt.logs,
        eventName: 'TestResult',
      });
      expect(logs.length).equal(1);
      expect(logs[0].args.value).equal(0n);
    }
  });
});
