import { task } from 'hardhat/config';
import { parseEther } from 'viem';
import { privateKeyToAccount } from 'viem/accounts'
import { chainInfo, deployments } from './chainInfo.ts';
import { castAsync, forgeAsync, getAccountKey, getPrivateKey, getRpcUrlKey } from './utils';

task("bridge", "bridge eth between chains")
  .addParam("amount", "the amount of eth to bridge")
  .addParam("src", "the src chain")
  .addParam("dst", "the dst chain")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ amount, src, dst, account, broadcast }) => {
    await forgeAsync({
      script: 'script/Bridge.s.sol:Bridge',
      env: {
        SRC: src,
        DST: dst,
        AMOUNT: parseEther(amount).toString(),
        PRIVATE_KEY: getAccountKey(account),
      },
      chain: src,
      broadcast,
    });
  });

task("add-liquidity", "add liquidity to bridge")
  .addParam("chain", "the chain to add liquidity to")
  .addParam("amount", "the amount of liquidity to add (in eth)")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chain, amount, account, broadcast }) => {
    await forgeAsync({
      script: 'script/Bridge.s.sol:AddLiquidity',
      env: {
        CHAIN: chain,
        AMOUNT: parseEther(amount).toString(),
        PRIVATE_KEY: getAccountKey(account),
      },
      chain,
      broadcast,
    });
  });

task("remove-liquidity", "remove liquidity from bridge")
  .addParam("chain", "the chain to remove liquidity from")
  .addParam("amount", "the amount of liquidity to remove (in eth)")
  .addParam("account", "the account to use (mainnet, testnet)")
  .addFlag("broadcast", "broadcast the transactions")
  .setAction(async ({ chain, amount, account, broadcast }) => {
    await forgeAsync({
      script: 'script/Bridge.s.sol:RemoveLiquidity',
      env: {
        CHAIN: chain,
        AMOUNT: parseEther(amount).toString(),
        PRIVATE_KEY: getAccountKey(account),
      },
      chain,
      broadcast,
    });
  });

task("check-all-liquidity", "check liquidity balances across multiple chains")
  .addOptionalParam("chains", "comma-separated list of chains")
  .addParam("account", "the account to use (mainnet, testnet)")
  .setAction(async ({ chains, account }, hre) => {
    chains = chains
      ? chains.toLowerCase().split(",").map((chain: string) => chain.trim())
      : Object.keys(chainInfo);
    chains = chains.filter((chain: string) => !!deployments[chain]?.DcntEth);
    for (const chain of chains) {
      console.log(`\nChecking ${chain}:`);
      await hre.run("check-liquidity", { chain, account });
    }
  });

task("check-liquidity", "check liquidity balances")
  .addParam("chain", "the chain to check liquidity on")
  .addParam("account", "the account to use (mainnet, testnet)")
  .setAction(async ({ chain, account }) => {
    const rpcUrlKey = getRpcUrlKey(chain);
    const { address } = privateKeyToAccount(getPrivateKey(account));
    const { DecentEthRouter, DcntEth } = deployments[chain];
    const { weth: wethAddr } = chainInfo[chain];

    const [weth, dcntEth, liq] = await Promise.all([
      castAsync(`${wethAddr} 'balanceOf(address)(uint256)' ${DecentEthRouter}`, rpcUrlKey),
      castAsync(`${DcntEth} 'balanceOf(address)(uint256)' ${DecentEthRouter}`, rpcUrlKey),
      castAsync(`${DcntEth} 'balanceOf(address)(uint256)' ${address}`, rpcUrlKey),
    ]);

    console.log("Weth:", weth);
    console.log("DcntEth:", dcntEth);
    console.log("Liquidity:", liq);
  });
