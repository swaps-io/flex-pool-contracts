import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import hre from 'hardhat';

describe('Approve', function () {
  async function deployFixture() {
    const publicClient = await hre.viem.getPublicClient();

    const token = await hre.viem.deployContract('TestToken', [
      'Test Token', // name
      'TT', // symbol
      6, // decimals
    ]);

    const infiniteSpender = await hre.viem.deployContract('TestSpender');
    const temporarySpender = await hre.viem.deployContract('TestSpender');

    const approveTest = await hre.viem.deployContract('TestApprove', [
      token.address, // token
    ]);
    await approveTest.write.provideInfiniteApprove([
      infiniteSpender.address, // spender
    ]);

    await token.write.mint([
      approveTest.address, // account
      888_777n, // assets
    ]);

    return {
      publicClient,
      infiniteSpender,
      temporarySpender,
      approveTest,
    };
  }

  it('Should test infinite approve', async function () {
    const { publicClient, infiniteSpender, approveTest } = await loadFixture(deployFixture);

    {
      const hash = await approveTest.write.testInfiniteApprove([
        infiniteSpender.address, // spender
        300_000n, // assets
        '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', // to
      ]);

      const receipt = await publicClient.getTransactionReceipt({ hash });
      console.log(`TestApprove.testInfiniteApprove 1st gas: ${receipt.gasUsed}`);
    }

    {
      const hash = await approveTest.write.testInfiniteApprove([
        infiniteSpender.address, // spender
        300_000n, // assets
        '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', // to
      ]);

      const receipt = await publicClient.getTransactionReceipt({ hash });
      console.log(`TestApprove.testInfiniteApprove 2nd gas: ${receipt.gasUsed}`);
    }

    {
      const hash = await approveTest.write.testInfiniteApprove([
        infiniteSpender.address, // spender
        288_777n, // assets
        '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', // to
      ]);

      const receipt = await publicClient.getTransactionReceipt({ hash });
      console.log(`TestApprove.testInfiniteApprove 3rd gas: ${receipt.gasUsed}`);
    }
  });

  it('Should test temporary approve', async function () {
    const { publicClient, temporarySpender, approveTest } = await loadFixture(deployFixture);

    {
      const hash = await approveTest.write.testTemporaryApprove([
        temporarySpender.address, // spender
        300_000n, // assets
        '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', // to
      ]);

      const receipt = await publicClient.getTransactionReceipt({ hash });
      console.log(`TestApprove.testTemporaryApprove 1st gas: ${receipt.gasUsed}`);
    }

    {
      const hash = await approveTest.write.testTemporaryApprove([
        temporarySpender.address, // spender
        300_000n, // assets
        '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', // to
      ]);

      const receipt = await publicClient.getTransactionReceipt({ hash });
      console.log(`TestApprove.testTemporaryApprove 2nd gas: ${receipt.gasUsed}`);
    }

    {
      const hash = await approveTest.write.testTemporaryApprove([
        temporarySpender.address, // spender
        288_777n, // assets
        '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', // to
      ]);

      const receipt = await publicClient.getTransactionReceipt({ hash });
      console.log(`TestApprove.testTemporaryApprove 3rd gas: ${receipt.gasUsed}`);
    }
  });
});
