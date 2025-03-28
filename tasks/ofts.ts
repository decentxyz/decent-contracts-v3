import { task, subtask } from 'hardhat/config';
import { chainInfo } from './chainInfo.ts';
import { forgeAsync, getAccountKey } from './utils';

task("allow-oft", "allow oft interaction with utb oft adapter")
  .addParam("chains", "the chains to allow the oft")
  .addParam("oft", "the erc20 symbol of the oft")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chains, oft, account, broadcast }, hre) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim());
    for (const chain of chains) {
      await hre.run("_allow-oft", { chain, oft, account, broadcast });
    }
  });

subtask("_allow-oft", "allow oft interaction with utb oft adapter")
  .addParam("chain", "the chain to allow the oft")
  .addParam("oft", "the erc20 symbol of the oft")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chain, oft: oftSymbol, account, broadcast }) => {
    const oft = chainInfo[chain]?.['ofts']?.[oftSymbol];
    const oftAdapter = chainInfo[chain]?.['ofts']?.[`${oftSymbol}_OftAdapter`] ?? oft;
    await forgeAsync({
      script: 'script/OFTs.s.sol:PermissionOft',
      env: {
        CHAIN: chain,
        OFT: oft,
        OFT_ADAPTER: oftAdapter,
        PRIVATE_KEY: getAccountKey(account),
      },
      chain,
      broadcast,
    });
  });

task("disallow-oft", "disallow oft interaction with utb oft adapter")
  .addParam("chains", "the chains to disallow the oft")
  .addParam("oft", "the erc20 symbol of the oft")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chains, oft, account, broadcast }, hre) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim());
    for (const chain of chains) {
      await hre.run("_disallow-oft", { chain, oft, account, broadcast });
    }
  });

subtask("_disallow-oft", "disallow oft interaction with utb oft adapter")
  .addParam("chain", "the chain to disallow the oft")
  .addParam("oft", "the erc20 symbol of the oft")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chain, oft: oftSymbol, account, broadcast }) => {
    const oft = chainInfo[chain]?.['ofts']?.[oftSymbol];
    await forgeAsync({
      script: 'script/OFTs.s.sol:DisallowOft',
      env: {
        CHAIN: chain,
        OFT: oft,
        PRIVATE_KEY: getAccountKey(account),
      },
      chain,
      broadcast,
    });
  });

task("allow-yield-oft", "allow yield oft interaction with utb yield oft adapter")
  .addParam("chains", "the chains to allow the yield oft")
  .addParam("oft", "the erc20 symbol of the yield oft")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chains, oft, account, broadcast }, hre) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim());
    for (const chain of chains) {
      await hre.run("_allow-yield-oft", { chain, oft, account, broadcast });
    }
  });

subtask("_allow-yield-oft", "allow yield oft interaction with utb yield oft adapter")
  .addParam("chain", "the chain to allow the yield oft")
  .addParam("oft", "the erc20 symbol of the yield oft")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chain, oft: oftSymbol, account, broadcast }) => {
    const oft = chainInfo[chain]?.['yieldOfts']?.[oftSymbol]?.['oft'];
    const underlying = chainInfo[chain]?.['yieldOfts']?.[oftSymbol]?.['underlying'];
    const l1Router = chainInfo[chain]?.['yieldOfts']?.[oftSymbol]?.['l1Router'];
    const l1ChainId = chainInfo[chain]?.['yieldOfts']?.[oftSymbol]?.['l1ChainId'];

    await forgeAsync({
      script: 'script/OFTs.s.sol:PermissionYieldOft',
      env: {
        CHAIN: chain,
        OFT: oft,
        UNDERLYING: underlying,
        L1_ROUTER: l1Router,
        L1_CHAIN_ID: l1ChainId,
        PRIVATE_KEY: getAccountKey(account),
      },
      chain,
      broadcast,
    });
  });

task("disallow-yield-oft", "disallow yield oft interaction with utb yield oft adapter")
  .addParam("chains", "the chains to disallow the yield oft")
  .addParam("oft", "the erc20 symbol of the yield oft")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chains, oft, account, broadcast }, hre) => {
    chains = chains.toLowerCase().split(",").map((chain: string) => chain.trim());
    for (const chain of chains) {
      await hre.run("_disallow-yield-oft", { chain, oft, account, broadcast });
    }
  });

subtask("_disallow-yield-oft", "disallow yield oft interaction with utb yield oft adapter")
  .addParam("chain", "the chain to disallow the yield oft")
  .addParam("oft", "the erc20 symbol of the yield oft")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chain, oft: oftSymbol, account, broadcast }) => {
    const oft = chainInfo[chain]?.['yieldOfts']?.[oftSymbol]?.['oft'];
    await forgeAsync({
      script: 'script/OFTs.s.sol:DisallowYieldOft',
      env: {
        CHAIN: chain,
        OFT: oft,
        PRIVATE_KEY: getAccountKey(account),
      },
      chain,
      broadcast,
    });
  });
