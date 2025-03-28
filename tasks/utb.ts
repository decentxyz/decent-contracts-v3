import { task, subtask } from 'hardhat/config';
import { forgeAsync, getAccountKey, encodeUTBConfig, encodeUTBConfigArray } from './utils';
import { encodeAbiParameters } from 'viem';
import { chainInfo, deployments } from './chainInfo';

task("deploy", "deploy bridge and utb")
  .addParam("chain", "the chain to deploy to")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chain, account, broadcast }, hre) => {
    await hre.run("_deploy", { chain, account, broadcast });
  });

task("deploy-chains", "deploy bridge and utb")
  .addParam("chains", "the chains to deploy to")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chains, account, broadcast }, hre) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim());
    for (const chain of chains) {
      await hre.run("_deploy", { chain, account, broadcast });
    }
  });

task("configure", "configure bridge and utb")
  .addParam("chain", "the chain to configure")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chain, account, broadcast }, hre) => {
    await hre.run("_configure", { chain, account, broadcast });
  });

task("configure-chains", "configure bridge and utb")
  .addParam("chains", "the chains to configure")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chains, account, broadcast }, hre) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim());
    for (const chain of chains) {
      await hre.run("_configure", { chain, account, broadcast });
    }
  });

subtask("_deploy")
  .addParam("chain", "the chain to deploy to")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chain, account, broadcast }) => {
    const { utbConfig } = chainInfo[chain];
    await forgeAsync({
      script: 'script/UTB.s.sol:Deploy',
      env: {
        CHAIN: chain,
        PRIVATE_KEY: getAccountKey(account),
        UTB_CONFIG: encodeUTBConfig(utbConfig)
      },
      chain,
      broadcast,
    });
  });

subtask("_configure")
  .addParam("chain", "the chain to deploy to")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chain, account, broadcast }) => {
    const { utbConfig } = chainInfo[chain];
    await forgeAsync({
      script: 'script/UTB.s.sol:Configure',
      env: {
        CHAIN: chain,
        PRIVATE_KEY: getAccountKey(account),
        UTB_CONFIG: encodeUTBConfig(utbConfig)
      },
      chain,
      broadcast,
    });
  });

task("connect", "connect bridge and utb between chains")
  .addParam("chains", "comma-separated list of chains")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chains, account, broadcast }, hre) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim());
    for (const src of chains) {
      await hre.run("_connect", { src, chains: chains.join(','), account, broadcast });
    }
  });

task("connect-chain", "connect a chain bidirectionally to multiple chains")
  .addParam("chain", "the new chain to connect")
  .addParam("chains", "comma-separated list of existing chains")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chain, chains, account, broadcast }, hre) => {
    await hre.run("connect-src", { src: chain, chains, account, broadcast });
    await hre.run("connect-dst", { dst: chain, chains, account, broadcast });
  });

task("connect-src", "connect a src chain unidirectionally to multiple dst chains on the src chain")
  .addParam("src", "the src chain")
  .addParam("chains", "comma-separated list of dst chains")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ src, chains, account, broadcast }, hre) => {
    await hre.run("_connect", { src, chains, account, broadcast });
  });

task("connect-dst", "connect a dst chain unidirectionally to multiple src chains on the src chain")
  .addParam("dst", "the dst chain")
  .addParam("chains", "comma-separated list of src chains")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ dst, chains, account, broadcast }, hre) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim());
    for (const src of chains) {
      await hre.run("_connect", { src, chains: dst, account, broadcast });
    }
  });

subtask("_connect")
  .addParam("src", "the src chain")
  .addParam("chains", "comma-separated list of chains")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ src, chains, account, broadcast }) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim()).filter((dst: string) => dst != src);

    const { utbConfig: srcConfig } = chainInfo[src];

    const dstConfigs = chains.map((dst: string) => {
      const { utbConfig: dstConfig } = chainInfo[dst];
      return {
        decentBridge: srcConfig.decentBridge && dstConfig.decentBridge,
        stargateBridge: srcConfig.stargateBridge && dstConfig.stargateBridge,
        oftBridge: srcConfig.oftBridge && dstConfig.oftBridge,
        yieldOftBridge: srcConfig.yieldOftBridge && dstConfig.yieldOftBridge,
        hyperlaneBridge: srcConfig.hyperlaneBridge && dstConfig.hyperlaneBridge,
        uniswap: false,
        anyswap: false
      };
    });

    await forgeAsync({
      script: 'script/UTB.s.sol:Connect',
      env: {
        SRC: src,
        DST_CHAINS: encodeAbiParameters([{ type: 'string[]' }], [chains]),
        UTB_CONFIGS: encodeUTBConfigArray(dstConfigs),
        PRIVATE_KEY: getAccountKey(account),
      },
      chain: src,
      broadcast,
    });
  });

task("withdraw", "withdraw funds from a contract")
  .addParam("chain", "the chain to withdraw from")
  .addParam("contract", "the contract name to withdraw from")
  .addParam("to", "address to withdraw to")
  .addParam("amount", "amount to withdraw")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chain, contract, to, amount, account, broadcast }) => {
    const contractAddress = deployments[chain][contract];

    await forgeAsync({
      script: 'script/UTB.s.sol:Withdraw',
      env: {
        CHAIN: chain,
        CONTRACT: contractAddress,
        TO: to,
        AMOUNT: amount,
        PRIVATE_KEY: getAccountKey(account),
      },
      chain,
      broadcast,
    });
  });
