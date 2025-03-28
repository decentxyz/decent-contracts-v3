# Task CLI Reference

This guide documents all available Hardhat tasks and Foundry scripts used to deploy, configure, and maintain the UTB protocol.

## UTB Tasks

**Deploy bridge and UTB**  
npx hardhat deploy --chain ethereum --account mainnet

**Configure bridge and UTB**  
npx hardhat configure --chain ethereum --account mainnet

**Connect multiple chains bidirectionally**  
npx hardhat connect --chains ethereum,arbitrum --account mainnet

**Connect a new chain bidirectionally to existing chains**  
npx hardhat connect-chain --chain optimism --chains ethereum,arbitrum --account mainnet

**Connect source chain to multiple destinations**  
npx hardhat connect-src --src optimism --chains ethereum,arbitrum --account mainnet

**Connect destination chain to multiple sources**  
npx hardhat connect-dst --dst optimism --chains ethereum,arbitrum --account mainnet

## Bridge Tasks

**Bridge ETH between chains**  
npx hardhat bridge --amount 0.001 --src ethereum --dst arbitrum --account mainnet

**Add liquidity to bridge**  
npx hardhat add-liquidity --chain ethereum --amount 0.01 --account mainnet

**Remove liquidity from bridge**  
npx hardhat remove-liquidity --chain ethereum --amount 0.01 --account mainnet

**Check liquidity balances**  
npx hardhat check-liquidity --chain ethereum --account mainnet

## Adapter Tasks

**Set Uniswapper routers on multiple chains**  
npx hardhat set-uniswapper-routers --chains ethereum,arbitrum --account mainnet

**Deploy AnySwapper**  
npx hardhat deploy-anyswapper --chain ethereum --account mainnet

**Configure AnySwapper**  
npx hardhat configure-anyswapper --chain ethereum --account mainnet

**Deploy Yield OFT Adapter**  
npx hardhat deploy-yield-oft-adapter --chain ethereum --account mainnet

**Configure Yield OFT Adapter**  
npx hardhat configure-yield-oft-adapter --chain ethereum --account mainnet

## OFT Tasks

**Allow OFT interaction**  
npx hardhat allow-oft --chains ethereum,arbitrum --oft APE --account mainnet

**Disallow OFT interaction**  
npx hardhat disallow-oft --chains ethereum,arbitrum --oft APE --account mainnet

**Allow Yield OFT interaction**  
npx hardhat allow-yield-oft --chains ethereum,arbitrum --oft ApeETH --account mainnet

**Disallow Yield OFT interaction**  
npx hardhat disallow-yield-oft --chains "ethereum,arbitrum" --oft ApeETH --account mainnet

## Verification Tasks

**Verify all contracts on a specific chain**  
npx hardhat verify-chain --chain ethereum

**Verify individual contracts on a chain**  
npx hardhat verify-contract --chain ethereum --contract UTB

## Debugging Tasks

**Log configuration for a chain**  
npx hardhat log-config --chain ethereum

**Debug remotes (check all chains if no chains specified)**  
npx hardhat debug-remotes --chains ethereum,arbitrum

**Debug contracts**  
npx hardhat debug-contracts --chains ethereum,arbitrum

**Simulate a transaction**  
hh simulate --calldata '0x0' --from '0x0' --to '0x0' --value 0 --chain ethereum
