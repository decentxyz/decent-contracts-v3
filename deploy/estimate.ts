import * as ethers from 'ethers';
import { estimateDeployFee, getWallet, verifyEnoughBalance } from "./utils";
import { chainInfo } from '../tasks/chainInfo.ts';
import { getPrivateKey, getAccountKey } from '../tasks/utils';
import { privateKeyToAccount } from 'viem/accounts';
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

  const estimations: Promise<bigint>[] = [];

  if (utbConfig.decentBridge) {
    estimations.push(
      estimateDeployFee("DecentBridgeExecutor", [weth, gasIsEth]),
      estimateDeployFee("DecentEthRouter", [weth, gasIsEth, ethers.ZeroAddress]),
      estimateDeployFee("DcntEth", [layerZeroV2Endpoint])
    );
  }

  estimations.push(
    estimateDeployFee("UTB"),
    estimateDeployFee("UTBExecutor"),
    estimateDeployFee("UTBFeeManager", [feeSigner])
  );

  if (utbConfig.uniswap) {
    estimations.push(estimateDeployFee("UniSwapper"));
  }
  if (utbConfig.anyswap) {
    estimations.push(estimateDeployFee("AnySwapper"));
  }

  if (utbConfig.decentBridge) {
    estimations.push(estimateDeployFee("DecentBridgeAdapter", [gasIsEth, decimals, decentBridgeToken]));
  }

  if (utbConfig.stargateBridge) {
    estimations.push(estimateDeployFee("StargateBridgeAdapter", [decimals, stargateFactory]));
  }

  if (utbConfig.oftBridge) {
    estimations.push(estimateDeployFee("OftBridgeAdapter", [decimals]));
  }

  if (utbConfig.yieldOftBridge) {
    estimations.push(estimateDeployFee("YieldOftBridgeAdapter", [decimals]));
  }

  if (utbConfig.hyperlaneBridge) {
    estimations.push(estimateDeployFee("HyperlaneBridgeAdapter", [decimals, hyperlaneMailbox]));
  }

  const values = await Promise.all(estimations);
  const deploymentFee = values.reduce((a, c) => a + c, 0n);
  console.log(`Total estimated deployment cost: ${ethers.formatEther(deploymentFee)} ETH`);

  const wallet = getWallet();
  await verifyEnoughBalance(wallet, deploymentFee);
}
