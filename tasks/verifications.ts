import { task } from 'hardhat/config';
import { ChainInfo, chainInfo, deployments } from './chainInfo.ts';
import { privateKeyToAccount } from 'viem/accounts'
import { execAsync, getPrivateKey } from './utils';

const constructors: Record<string, (chainInfo: ChainInfo) => string> = {
  ['DecentBridgeExecutor']: ({ gasIsEth, weth }: ChainInfo) => {
    return `'constructor(address,bool)' '${weth}' ${gasIsEth}`;
  },

  ['DecentEthRouter']: ({ chainKey, gasIsEth, weth }: ChainInfo) => {
    return `'constructor(address,bool,address)' '${weth}' ${gasIsEth} '${deployments[chainKey].DecentBridgeExecutor}'`;
  },

  ['DcntEth']: ({ layerZeroV2Endpoint }: ChainInfo) => {
    return `'constructor(address)' '${layerZeroV2Endpoint}'`;
  },

  ['UTBFeeManager']: ({ feeSigner }: ChainInfo) => {
    return `'constructor(address)' '${feeSigner}'`;
  },

  ['DecentBridgeAdapter']: ({ gasIsEth, decimals, decentBridgeToken }: ChainInfo) => {
    return `'constructor(bool,uint8,address)' ${gasIsEth} ${decimals} '${decentBridgeToken}'`;
  },

  ['StargateBridgeAdapter']: ({ decimals, stargateFactory }: ChainInfo) => {
    return `'constructor(uint8,address)' ${decimals} '${stargateFactory}'`;
  },

  ['OftBridgeAdapter']: ({ decimals }: ChainInfo) => {
    return `'constructor(uint8)' ${decimals}`;
  },

  ['YieldOftBridgeAdapter']: ({ decimals }: ChainInfo) => {
    return `'constructor(uint8)' ${decimals}`;
  },

  ['HyperlaneBridgeAdapter']: ({ decimals, hyperlaneMailbox }: ChainInfo) => {
    return `'constructor(uint8,address)' ${decimals} '${hyperlaneMailbox}'`;
  },
};

const paths: Record<string, string> = {
  ['DecentBridgeExecutor']: 'src/DecentBridgeExecutor.sol:DecentBridgeExecutor',
  ['DecentEthRouter']: 'src/DecentEthRouter.sol:DecentEthRouter',
  ['DcntEth']: 'src/DcntEth.sol:DcntEth',
  ['UTB']: 'src/UTB.sol:UTB',
  ['UTBExecutor']: 'src/UTBExecutor.sol:UTBExecutor',
  ['UTBFeeManager']: 'src/UTBFeeManager.sol:UTBFeeManager',
  ['UniSwapper']: 'src/swappers/UniSwapper.sol:UniSwapper',
  ['AnySwapper']: 'src/swappers/AnySwapper.sol:AnySwapper',
  ['DecentBridgeAdapter']: 'src/bridge_adapters/DecentBridgeAdapter.sol:DecentBridgeAdapter',
  ['StargateBridgeAdapter']: 'src/bridge_adapters/StargateBridgeAdapter.sol:StargateBridgeAdapter',
  ['OftBridgeAdapter']: 'src/bridge_adapters/OftBridgeAdapter.sol:OftBridgeAdapter',
  ['YieldOftBridgeAdapter']: 'src/bridge_adapters/YieldOftBridgeAdapter.sol:YieldOftBridgeAdapter',
  ['HyperlaneBridgeAdapter']: 'src/bridge_adapters/HyperlaneBridgeAdapter.sol:HyperlaneBridgeAdapter',
}

const verifyContract = (contract: string, chainInfo: ChainInfo) => {
  const { chainId, chainKey, explorerApiUrl, explorerType } = chainInfo;
  const address = deployments[chainKey][contract];
  const path = paths[contract];
  const args = constructors[contract] ? `--constructor-args $(cast abi-encode ${constructors[contract](chainInfo)})` : '';
  const apiKey = process.env[chainKey.toUpperCase() + '_SCANNER_API_KEY'];
  const etherscan = `--verifier-url '${explorerApiUrl}' --etherscan-api-key '${apiKey}'`;
  const blockscout = `--verifier blockscout --verifier-url '${explorerApiUrl}?'`;
  const verifier = explorerType == 'etherscan' ? etherscan : blockscout;
  const command = `forge verify-contract ${address} ${path} ${args} --watch --chain-id ${chainId} ${verifier}`;
  return command.replace(/\s+/g, ' ');
}

task("verify-chain", "verify all contracts on a chain")
  .addParam("chain", "the chain to verify")
  .setAction(async ({ chain }, hre) => {
    const contracts = [
      'DecentBridgeExecutor',
      'DecentEthRouter',
      'DcntEth',
      'UTB',
      'UTBExecutor',
      'UTBFeeManager',
      'UniSwapper',
      'AnySwapper',
      'DecentBridgeAdapter',
      'StargateBridgeAdapter',
      'OftBridgeAdapter',
      'YieldOftBridgeAdapter',
      'HyperlaneBridgeAdapter',
    ].filter(contract => deployments[chain]?.[contract]);

    const verifyWithThrottle = async (contract: string, index: number) => {
      await new Promise(resolve => setTimeout(resolve, index * 2000));
      return hre.run("verify-contract", { chain, contract }).catch(console.error);
    };

    await Promise.all(
      contracts.map((contract, index) => verifyWithThrottle(contract, index))
    );
  });

task("verify-contract", "verify a contract on a chain")
  .addParam("contract", "the contract to verify")
  .addParam("chain", "the chain to verify")
  .setAction(async ({ chain, contract }) => {
    const { address: feeSigner } = privateKeyToAccount(getPrivateKey('FEE_SIGNER'));
    chainInfo[chain] = {
      ...chainInfo[chain],
      feeSigner,
    }
    const cmd = verifyContract(contract, chainInfo[chain]);
    console.log(cmd);
    await execAsync(cmd);
  });
