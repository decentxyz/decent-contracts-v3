import { deployContract } from './utils';
import { chainInfo } from '../tasks/chainInfo.ts';
import { privateKeyToAccount } from 'viem/accounts';
import { getPrivateKey } from '../tasks/utils';
import * as hre from 'hardhat';

export default async function () {
  const {
    weth,
    gasIsEth,
    layerZeroV2Endpoint,
    decentBridgeToken,
    decimals,
    stargateFactory,
    hyperlaneMailbox,
    utbConfig,
  } = chainInfo[hre.network.name];
  const { address: feeSigner } = privateKeyToAccount(getPrivateKey('FEE_SIGNER'));

  const addresses: Record<string, string> = {};

  if (utbConfig.decentBridge) {
    const decentBridgeExecutor = await deployContract('DecentBridgeExecutor', [weth, gasIsEth]);
    const decentEthRouter = await deployContract('DecentEthRouter', [weth, gasIsEth, await decentBridgeExecutor.getAddress()]);
    const dcntEth = await deployContract('DcntEth', [layerZeroV2Endpoint]);

    addresses.DcntEth = await dcntEth.getAddress();
    addresses.DecentBridgeExecutor = await decentBridgeExecutor.getAddress();
    addresses.DecentEthRouter = await decentEthRouter.getAddress();
  }

  const utb = await deployContract('UTB');
  const utbExecutor = await deployContract('UTBExecutor');
  const utbFeeManager = await deployContract('UTBFeeManager', [feeSigner]);

  addresses.UTB = await utb.getAddress();
  addresses.UTBExecutor = await utbExecutor.getAddress();
  addresses.UTBFeeManager = await utbFeeManager.getAddress();

  if (utbConfig.uniswap) {
    const uniSwapper = await deployContract('UniSwapper');
    addresses.UniSwapper = await uniSwapper.getAddress();
  }

  if (utbConfig.anyswap) {
    const anySwapper = await deployContract('AnySwapper');
    addresses.AnySwapper = await anySwapper.getAddress();
  }

  if (utbConfig.decentBridge) {
    const decentBridgeAdapter = await deployContract('DecentBridgeAdapter', [gasIsEth, decimals, decentBridgeToken]);
    addresses.DecentBridgeAdapter = await decentBridgeAdapter.getAddress();
  }

  if (utbConfig.stargateBridge) {
    const stargateBridgeAdapter = await deployContract('StargateBridgeAdapter', [decimals, stargateFactory]);
    addresses.StargateBridgeAdapter = await stargateBridgeAdapter.getAddress();
  }

  if (utbConfig.oftBridge) {
    const oftBridgeAdapter = await deployContract('OftBridgeAdapter', [decimals]);
    addresses.OftBridgeAdapter = await oftBridgeAdapter.getAddress();
  }

  if (utbConfig.yieldOftBridge) {
    const yieldOftBridgeAdapter = await deployContract('YieldOftBridgeAdapter', [decimals]);
    addresses.YieldOftBridgeAdapter = await yieldOftBridgeAdapter.getAddress();
  }

  if (utbConfig.hyperlaneBridge) {
    const hyperlaneBridgeAdapter = await deployContract('HyperlaneBridgeAdapter', [decimals, hyperlaneMailbox]);
    addresses.HyperlaneBridgeAdapter = await hyperlaneBridgeAdapter.getAddress();
  }

  console.log({ [hre.network.name]: addresses });
}
