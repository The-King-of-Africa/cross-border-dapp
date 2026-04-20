const fs = require('fs');
const path = require('path');
require('dotenv').config();

const outputPath = path.join(__dirname, '..', 'frontend', 'env-config.js');

const config = {
  defaultContractAddress: process.env.NEXT_PUBLIC_CONTRACT_ADDRESS || '',
  expectedChainId: Number(process.env.NEXT_PUBLIC_CHAIN_ID || process.env.GANACHE_CHAIN_ID || '5777'),
  networkLabel: process.env.NEXT_PUBLIC_NETWORK_LABEL || process.env.GANACHE_NETWORK_NAME || 'Ganache Local',
  minimumInvestmentWei: process.env.NEXT_PUBLIC_MINIMUM_INVESTMENT_WEI || process.env.MINIMUM_INVESTMENT || '1000000000000000'
};

const file = `window.__APP_CONFIG__ = ${JSON.stringify(config, null, 2)};\n`;
fs.writeFileSync(outputPath, file);
console.log(`Generated ${outputPath}`);
