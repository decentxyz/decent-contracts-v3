import { task } from 'hardhat/config';
import { forgeAsync, getAccountKey } from './utils';

task("set-uniswapper-routers", "sets the router on uniswappers")
  .addParam("chains", "comma-separated list of chains")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chains, account, broadcast }) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim());
    for (const chain of chains) {
      await forgeAsync({
        script: 'script/Adapters.s.sol:SetUniSwapperRouter',
        env: {
          CHAIN: chain,
          PRIVATE_KEY: getAccountKey(account),
        },
        chain,
        broadcast,
      });
    }
  });

task("deploy-anyswapper", "deploy anyswapper contract")
  .addParam("chains", "the chain to deploy to")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chains, account, broadcast }) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim());
    for (const chain of chains) {
      await forgeAsync({
        script: 'script/Adapters.s.sol:DeployAnySwapper',
        env: {
          CHAIN: chain,
          PRIVATE_KEY: getAccountKey(account),
        },
        chain,
        broadcast,
      });
    }
  });

task("configure-anyswapper", "set anyswapper configuration")
  .addParam("chains", "the chain to configure")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chains, account, broadcast }) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim());
    for (const chain of chains) {
      await forgeAsync({
        script: 'script/Adapters.s.sol:ConfigureAnySwapper',
        env: {
          CHAIN: chain,
          PRIVATE_KEY: getAccountKey(account),
        },
        chain,
        broadcast,
      });
    }
  });

task("deploy-oft-adapter", "deploy oft bridge adapter contract")
  .addParam("chains", "the chains to deploy to")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chains, account, broadcast }) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim());
    for (const chain of chains) {
      await forgeAsync({
        script: 'script/Adapters.s.sol:DeployOftBridgeAdapter',
        env: {
          CHAIN: chain,
          PRIVATE_KEY: getAccountKey(account),
        },
        chain,
        broadcast,
      });
    }
  });

task("configure-oft-adapter", "set oft bridge adapter configuration")
  .addParam("chains", "the chain to configure")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chains, account, broadcast }) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim());
    for (const chain of chains) {
      await forgeAsync({
        script: 'script/Adapters.s.sol:ConfigureOftBridgeAdapter',
        env: {
          CHAIN: chain,
          PRIVATE_KEY: getAccountKey(account),
        },
        chain,
        broadcast,
      });
    }
  });

task("deploy-yield-oft-adapter", "deploy yield oft bridge adapter contract")
  .addParam("chains", "the chains to deploy to")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chains, account, broadcast }) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim());
    for (const chain of chains) {
      await forgeAsync({
        script: 'script/Adapters.s.sol:DeployYieldOftBridgeAdapter',
        env: {
          CHAIN: chain,
          PRIVATE_KEY: getAccountKey(account),
        },
        chain,
        broadcast,
      });
    }
  });

task("configure-yield-oft-adapter", "set yield oft bridge adapter configuration")
  .addParam("chains", "the chains to configure")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chains, account, broadcast }) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim());
    for (const chain of chains) {
      await forgeAsync({
        script: 'script/Adapters.s.sol:ConfigureYieldOftBridgeAdapter',
        env: {
          CHAIN: chain,
          PRIVATE_KEY: getAccountKey(account),
        },
        chain,
        broadcast,
      });
    }
  });

task("deploy-hyperlane-adapter", "deploy hyperlane bridge adapter contract")
  .addParam("chains", "the chain to deploy to")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chains, account, broadcast }) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim());
    for (const chain of chains) {
      await forgeAsync({
        script: 'script/Adapters.s.sol:DeployHyperlaneBridgeAdapter',
        env: {
          CHAIN: chain,
          PRIVATE_KEY: getAccountKey(account),
        },
        chain,
        broadcast,
      });
    }
  });

task("configure-hyperlane-adapter", "set hyperlane bridge adapter configuration")
  .addParam("chain", "the chain to configure")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chains, account, broadcast }) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim());
    for (const chain of chains) {
      await forgeAsync({
        script: 'script/Adapters.s.sol:ConfigureHyperlaneBridgeAdapter',
        env: {
          CHAIN: chain,
          PRIVATE_KEY: getAccountKey(account),
        },
        chain,
        broadcast,
      });
    }
  });

task("add-hyperlane-warp-route", "add a hyperlane warp route")
  .addParam("src", "the src chain")
  .addParam("dst", "the dst chain")
  .addParam("localTokenRouter", "address of the local token router")
  .addParam("localToken", "address of the local token")
  .addParam("remoteToken", "address of the remote token")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ src, dst, account, localTokenRouter, localToken, remoteToken, broadcast }) => {
    await forgeAsync({
      script: 'script/Adapters.s.sol:AddHyperlaneWarpRoute',
      env: {
        SRC: src,
        DST: dst,
        PRIVATE_KEY: getAccountKey(account),
        LOCAL_TOKEN_ROUTER: localTokenRouter,
        LOCAL_TOKEN: localToken,
        REMOTE_TOKEN: remoteToken,
      },
      chain: src,
      broadcast,
    });
  });
