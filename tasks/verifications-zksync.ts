import { task } from 'hardhat/config';
import { ChainInfo, chainInfo, deployments } from '../tasks/chainInfo.ts';

const constructors: Record<string, (chainInfo: ChainInfo) => (string | number | boolean)[]> = {
  ['DecentBridgeExecutor']: ({ gasIsEth, weth }: ChainInfo) => [weth, gasIsEth],
  ['DecentEthRouter']: ({ chainKey, gasIsEth, weth }: ChainInfo) => [weth, gasIsEth, deployments[chainKey]?.DecentBridgeExecutor],
  ['DcntEth']: ({ layerZeroV2Endpoint }: ChainInfo) => [layerZeroV2Endpoint],
  ['DecentBridgeAdapter']: ({ gasIsEth, decentBridgeToken }: ChainInfo) => [gasIsEth, decentBridgeToken],
};

const paths: Record<string, string> = {
  ['DecentBridgeExecutor']: 'src/DecentBridgeExecutor.sol:DecentBridgeExecutor',
  ['DecentEthRouter']: 'src/DecentEthRouter.sol:DecentEthRouter',
  ['DcntEth']: 'src/DcntEth.sol:DcntEth',
  ['UTB']: 'src/UTB.sol:UTB',
  ['UTBExecutor']: 'src/UTBExecutor.sol:UTBExecutor',
  ['UTBFeeManager']: 'src/UTBFeeManager.sol:UTBFeeManager',
  ['UniSwapper']: 'src/swappers/UniSwapper.sol:UniSwapper',
  ['DecentBridgeAdapter']: 'src/bridge_adapters/DecentBridgeAdapter.sol:DecentBridgeAdapter',
  ['StargateBridgeAdapter']: 'src/bridge_adapters/StargateBridgeAdapter.sol:StargateBridgeAdapter',
}

export const verifyContractZkSync = (contract: string, chainInfo: ChainInfo) => {
  const { chainKey } = chainInfo;
  return {
    address: deployments[chainKey][contract],
    contract: paths[contract],
    constructorArguments: constructors[contract]?.(chainInfo) ?? [],
  }
}

task("verify-zksync", "verify all contracts on zksync")
  .setAction(async (taskArguments, hre) => {
    const contracts = [
      'DecentBridgeExecutor',
      'DecentEthRouter',
      'DcntEth',
      'UTB',
      'UTBExecutor',
      'UTBFeeManager',
      'UniSwapper',
      'DecentBridgeAdapter',
      'StargateBridgeAdapter',
    ];

    for ( const contract of contracts ) {
      await hre.run("verify-contract-zksync", { contract });
    }
  });

task("verify-contract-zksync", "verify a contract on zksync")
  .addParam("contract", "the contract to verify")
  .setAction(async ({ contract }, hre) => {
    const verification = verifyContractZkSync(contract, chainInfo.zksync);
    await hre.run("verify:verify", verification);
  });
