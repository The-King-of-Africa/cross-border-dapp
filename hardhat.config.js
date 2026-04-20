require('@nomicfoundation/hardhat-toolbox');
require('dotenv').config();

const GANACHE_RPC_URL = process.env.GANACHE_RPC_URL || 'http://127.0.0.1:7545';
const GANACHE_CHAIN_ID = Number(process.env.GANACHE_CHAIN_ID || '5777');
const MNEMONIC = process.env.MNEMONIC || 'test test test test test test test test test test test junk';
const INFURA_API_KEY = process.env.INFURA_API_KEY || '';

module.exports = {
  solidity: {
    version: '0.8.20',
    settings: {
      optimizer: { enabled: true, runs: 200 }
    }
  },
  paths: {
    sources: './contracts',
    cache: './cache',
    artifacts: './artifacts'
  },
  networks: {
    ganache: {
      url: GANACHE_RPC_URL,
      chainId: GANACHE_CHAIN_ID,
      accounts: { mnemonic: MNEMONIC }
    },
    sepolia: INFURA_API_KEY
      ? {
          url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
          accounts: { mnemonic: MNEMONIC }
        }
      : undefined
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY || ''
  }
};
