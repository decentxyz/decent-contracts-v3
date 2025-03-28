import { task } from 'hardhat/config';
import { Hex, decodeAbiParameters } from 'viem';
import { chainInfo, deployments } from './chainInfo';
import { castAsync, forgeAsync, getRpcUrlKey } from './utils';
import chalk from 'chalk';

task("log-config", "log the local configuration for a chain")
  .addParam("chain", "the chain to log")
  .setAction(async ({ chain }) => {
    await forgeAsync({
      script: 'script/Debug.s.sol:LogConfig',
      env: {
        CHAIN: chain,
      },
    });
  });

task("list-chains", "print a comma-separated list of all chains")
  .addOptionalParam("exclude", "list of chains to exclude")
  .addOptionalParam("contract", "list of chains with deployed contract")
  .addFlag("testnet", "list testnet chains")
  .setAction(async ({ exclude = [], testnet = false, contract }) => {
    const list = Object.values(chainInfo)
      .filter(c => !exclude.includes(c.chainKey))
      .filter(c => !contract || deployments[c.chainKey]?.[contract])
      .filter(c => c.testnet === testnet)
      .map(c => c.chainKey)
      .join(',');
    console.log(list);
  });

task("debug-remotes", "log contract state for debugging")
  .addOptionalParam("chains", "comma-separated list of chains")
  .setAction(async ({ chains }) => {
    chains = chains
      ? chains.toLowerCase().split(",").map((chain: string) => chain.trim())
      : Object.keys(chainInfo);

    type ErrorDetails = {
      chainPair: string;
      expected: { peer: string };
      actual: { peer: string };
      peerMatch: boolean;
    };

    const results: {
      passed: number;
      failed: number;
      errors: ErrorDetails[];
    } = {
      passed: 0,
      failed: 0,
      errors: []
    };

    const tableData = {};

    const trustedRemote = async (src: string, dst: string) => {
      const rpcUrl = getRpcUrlKey(src);
      const { DcntEth } = deployments[src];
      const { layerZeroV2ChainId: lzId } = chainInfo[dst];
      const path = await castAsync(`${DcntEth} 'peers(uint32)(bytes32)' ${lzId}`, rpcUrl) as Hex;
      const [peer] = decodeAbiParameters([{ type: 'address' }], path);
      return { peer };
    };

    const dstHandler = async (src: string, dst: string) => {
      const chainPair = `${src} -> ${dst}`;
      if (src !== dst) {
        const expected = {
          peer: deployments[dst]['DcntEth'],
        };
        const actual = await trustedRemote(src, dst);

        const peerMatch = expected.peer === actual.peer;

        if (peerMatch) {
          results.passed++;
        } else {
          results.failed++;
          results.errors.push({
            chainPair,
            expected,
            actual,
            peerMatch,
          });
        }

        return {
          [chainPair]: {
            'peer': peerMatch ? '✅' : '❌'
          }
        };
      }
    };

    const srcHandler = async (src: string) => {
      process.stdout.write("\r\x1b[K");
      process.stdout.write(`Checking ${src}...`);

      const results = await Promise.all(chains.map((dst: string) => dstHandler(src, dst)));

      results.forEach(result => {
        if (result) {
          Object.assign(tableData, result);
        }
      });
    };

    for (const src of chains) {
      await srcHandler(src);
    }

    process.stdout.write("\r\x1b[K");
    console.log(`Completed.\n`);
    console.table(tableData);
    console.log(`\nResults:\n`);
    console.log(chalk.green(`- Passed: ${results.passed}`));

    if (results.failed > 0) {
      console.log(chalk.red(`- Failed: ${results.failed}`));
      console.log(`\nFailed Chains:`);
      results.errors.forEach(({ chainPair, expected, actual, peerMatch }, i) => {
        console.log(`\n  ${i + 1}) Chain Pair: ${chainPair}\n`);
        console.log(chalk.red(`     Error: expected peer to be set to dstDcntEth\n`));
        if (!peerMatch) {
          console.log(chalk.green(`     Expected peer: ${expected.peer}`));
          console.log(chalk.red(`       Actual peer: ${actual.peer}`));
        }
      });
    }

    console.log('\n');
  });

task("debug-contracts", "log contract state for debugging")
  .addOptionalParam("chains", "comma-separated list of chains")
  .addOptionalParam("contracts", "comma-separated list of contracts to check")
  .setAction(async ({ chains, contracts }) => {
    const state: { [key: string]: { [key: string]: string } } = {
      "UniSwapper": {
        "uniswap_router()": "uniswap_router()(address)",
        "wrapped()": "wrapped()(address)",
      },
      "HyperlaneBridgeAdapter": {
        "mailbox()": "mailbox()(address)",
      },
    };

    chains = chains
      ? chains.toLowerCase().split(",").map((chain: string) => chain.trim())
      : Object.keys(chainInfo).filter(c => !chainInfo[c].testnet);

    contracts = contracts
      ? contracts.split(",").map((contract: string) => contract.trim())
      : Object.keys(state);

    for (const chain of chains) {
      const rpcUrlKey = getRpcUrlKey(chain);

      for (const contract of contracts) {
        const address = deployments[chain]?.[contract];
        if (!address) {
          console.log(`Missing ${contract} address for chain: ${chain}`);
          continue;
        }

        const methods = state[contract];

        for (const method in methods) {
          const result = await castAsync(`${address} '${methods[method]}'`, rpcUrlKey);
          console.log(`${chain}::${contract}::${method}`, result);
        }
      }
    }
  });

task("simulate", "simulate a transaction on a chain")
  .addParam("chain", "the chain to simulate on")
  .addParam("from", "the from address")
  .addParam("to", "the to address")
  .addParam("value", "the value in wei")
  .addParam("calldata", "the tx calldata")
  .setAction(async ({ chain, from, to, value, calldata }) => {
    await forgeAsync({
      script: 'script/Debug.s.sol:Simulate',
      env: {
        FROM: from,
        TO: to,
        VALUE: value,
        CALLDATA: calldata
      },
      chain
    });
  });

task("explorer-links", "Get explorer links for a contract across all chains")
  .addOptionalParam("contract", "the contract name to look up")
  .setAction(async ({ contract }) => {
    for (const chainKey of Object.keys(chainInfo)) {
      const chain = chainInfo[chainKey];

      if (contract) {
        const address = deployments[chainKey]?.[contract];
        if (address) {
          console.log(`${chain.explorerUrl}/address/${address}`);
        }
      } else {
        console.log(`${chain.explorerUrl}`);
      }
    }
  });
