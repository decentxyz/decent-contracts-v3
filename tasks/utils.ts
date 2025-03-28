import { exec, ExecOptions } from 'shelljs';
import { spawn } from 'child_process';
import { chainInfo, UTBConfig } from './chainInfo';
import { Hex, encodeAbiParameters } from 'viem';
import { ethers } from 'ethers';

export const getRpcUrlKey = (chain: string) => `${chain.toUpperCase()}_RPC_URL`;
export const getAccountKey = (account: string) => `${account.toUpperCase()}_PRIVATE_KEY`;
export const getPrivateKey = (account: string) => process.env[getAccountKey(account)] as Hex;
export const getEnv = (env: object) => Object.entries(env).map(([k, v]) => `${k}="${v}"`).join(' ');

const getGas = async (chain: string) => {
  const provider = new ethers.JsonRpcProvider(process.env[getRpcUrlKey(chain)]);
  const currentGas = Number((await provider.getFeeData()).gasPrice?.toString());
  return Math.round((currentGas * (chainInfo[chain].gasBuffer ?? 100)) / 100);
}

export const execAsync = async (command: string): Promise<string> => {
  return new Promise((resolve, reject) => {
    const [cmd, ...args] = command.split(' ');

    const proc = spawn(cmd, args, {
      stdio: 'inherit',
      shell: true,
      env: { ...process.env }
    });

    proc.on('close', (code) => code !== 0 ? reject(new Error(`Process exited with code ${code}`)) : resolve(''));
    proc.on('error', (err) => reject(err));
  });
}

export const execAsyncOutput = async (command: string, options: ExecOptions = {}): Promise<string> => {
  return new Promise((resolve, reject) => {
    exec(command, options, (code, stdout, stderr) => {
      (() => code !== 0 ? reject(new Error(stderr)) : resolve(stdout.trim()))();
    });
  });
}

export const forgeAsync = async ({
  script,
  env,
  chain,
  broadcast,
}: {
  script: string,
  env: Record<string, string | number | undefined>,
  chain?: string,
  broadcast?: boolean,
}) => {
  const rpcUrlKey = chain ? ` --rpc-url $${getRpcUrlKey(chain)}` : '';
  const broadcasts = broadcast ? ' --broadcast' : '';
  const simulations = chain && chainInfo[chain].skipSimulation ? ' --skip-simulation' : '';
  const gasPrice = chain && chainInfo[chain].gasBuffer ? ` --gas-price ${await getGas(chain)}` : '';
  const cmd = `${getEnv(env)} forge script ${script}${rpcUrlKey}${broadcasts}${simulations}${gasPrice} --legacy -vvvv`;
  console.log(cmd);
  return await execAsync(cmd);
};

export const castAsync = async (call: string, rpcUrlKey: string): Promise<string> => {
  const cmd = `cast call ${call} --rpc-url $${rpcUrlKey}`;
  return await execAsyncOutput(cmd, { silent: true });
}

const UtbConfigAbi = [
  { name: 'decentBridge', type: 'bool' },
  { name: 'stargateBridge', type: 'bool' },
  { name: 'oftBridge', type: 'bool' },
  { name: 'yieldOftBridge', type: 'bool' },
  { name: 'hyperlaneBridge', type: 'bool' },
  { name: 'uniswap', type: 'bool' },
  { name: 'anyswap', type: 'bool' }
];

export const encodeUTBConfig = (config: UTBConfig): string => {
  return encodeAbiParameters(
    [{ type: 'tuple', components: UtbConfigAbi }],
    [config]
  );
}

export const encodeUTBConfigArray = (configs: UTBConfig[]): string => {
  return encodeAbiParameters(
    [{ type: 'tuple[]', components: UtbConfigAbi }],
    [configs]
  );
}
