import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import hre from 'hardhat';
import { checksumAddress, encodeFunctionData, zeroAddress } from 'viem';

describe('Controller', function () {
  async function deployFixture() {
    const [ownerClient] = await hre.viem.getWalletClients();

    const controller = await hre.viem.deployContract('Controller', [
      ownerClient.account.address, // initialOwner
    ]);

    const controllable = await hre.viem.deployContract('TestControllable', [
      controller.address, // controller
    ]);

    const token = await hre.viem.deployContract('TestToken', [
      'Test Token', // name
      'TT', // symbol
      6, // decimals
    ]);

    return {
      ownerClient,
      controller,
      controllable,
      token,
    };
  }

  it('Should be able to call anyone of controllable', async function () {
    const { ownerClient, controllable } = await loadFixture(deployFixture);

    await ownerClient.writeContract({
      abi: controllable.abi,
      address: controllable.address,
      functionName: 'testAnyone',
      args: [],
    });
  });

  it('Should not be able to call only controller of controllable', async function () {
    const { ownerClient, controllable, controller } = await loadFixture(deployFixture);

    await expect(
      ownerClient.writeContract({
        abi: controllable.abi,
        address: controllable.address,
        functionName: 'testOnlyController',
        args: [],
      }),
    ).rejectedWith(
      `CallerNotController("${checksumAddress(ownerClient.account.address)}", "${checksumAddress(controller.address)}")`
    );
  });

  it('Should be able to call only controller of controllable via controller', async function () {
    const { ownerClient, controllable, controller } = await loadFixture(deployFixture);

    await ownerClient.writeContract({
      abi: controller.abi,
      address: controller.address,
      functionName: 'execute',
      args: [
        controllable.address, // target
        encodeFunctionData({
          abi: controllable.abi,
          functionName: 'testOnlyController',
          args: [],
        }), // data
        0n, // value
      ],
    });
  });

  it('Should be able to rescue token from controllable via controller', async function () {
    const { ownerClient, controllable, controller, token } = await loadFixture(deployFixture);

    await ownerClient.writeContract({
      abi: token.abi,
      address: token.address,
      functionName: 'mint',
      args: [
        controllable.address, // account
        123_456_789n, // assets
      ],
    })

    await ownerClient.writeContract({
      abi: controller.abi,
      address: controller.address,
      functionName: 'execute',
      args: [
        controllable.address, // target
        encodeFunctionData({
          abi: controllable.abi,
          functionName: 'rescue',
          args: [
            token.address, // asset
            111_222_333n, // amount
            '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', // to
          ],
        }), // data
        0n, // value
      ],
    });
  });

  it('Should be able to rescue native from controllable via controller', async function () {
    const { ownerClient, controllable, controller, token } = await loadFixture(deployFixture);

    await ownerClient.sendTransaction({
      to: controllable.address,
      value: 123_456_789n,
    });

    await ownerClient.writeContract({
      abi: controller.abi,
      address: controller.address,
      functionName: 'execute',
      args: [
        controllable.address, // target
        encodeFunctionData({
          abi: controllable.abi,
          functionName: 'rescue',
          args: [
            zeroAddress, // asset
            111_222_333n, // amount
            '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef', // to
          ],
        }), // data
        0n, // value
      ],
    });
  });
});
