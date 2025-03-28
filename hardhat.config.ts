import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomicfoundation/hardhat-foundry';
import '@nomicfoundation/hardhat-toolbox';
import '@matterlabs/hardhat-zksync';
// import '@matterlabs/hardhat-zksync-node';
// import '@matterlabs/hardhat-zksync-deploy';
// import '@matterlabs/hardhat-zksync-solc';
// import '@matterlabs/hardhat-zksync-verify';
import dotenv from 'dotenv';
import { local } from './deploy/local.ts';
import "./tasks";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.24',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      zksync: false,
    },
    ethereum: {
      url: 'https://rpc.ankr.com/eth',
      accounts: [process.env.MAINNET_PRIVATE_KEY as string],
      zksync: false,
    },
    zksync: {
      url: 'https://mainnet.era.zksync.io',
      accounts: [process.env.MAINNET_PRIVATE_KEY as string],
      zksync: true,
      ethNetwork: 'ethereum',
      verifyURL: 'https://https://explorer.zksync.io/contract_verification',
    },
    sepolia: {
      url: 'https://rpc.sepolia.dev',
      accounts: [process.env.TESTNET_PRIVATE_KEY as string],
      zksync: false,
    },
    zksync_sepolia: {
      url: 'https://sepolia.era.zksync.dev',
      accounts: [process.env.TESTNET_PRIVATE_KEY as string],
      zksync: true,
      ethNetwork: 'sepolia',
      verifyURL: 'https://sepolia.explorer.zksync.io/contract_verification',
    },
    zksync_localhost: {
      url: 'http://127.0.0.1:8011',
      accounts: local.zksync.accounts,
      zksync: true,
      ethNetwork: 'localhost',
    },
    zero: {
      url: 'https://zero-network.calderachain.xyz/http',
      accounts: [process.env.MAINNET_PRIVATE_KEY as string],
      zksync: true,
      ethNetwork: 'ethereum',
      verifyURL: 'https://explorer.zero.network/contract_verification',
    },
    abstract: {
      url: 'https://api.mainnet.abs.xyz',
      accounts: [process.env.MAINNET_PRIVATE_KEY as string],
      zksync: true,
      ethNetwork: 'ethereum',
      verifyURL: 'https://abscan.org/api',
    },
  },
  zksolc: {
    version: 'latest',
    settings: {},
  },
};

export default config;
