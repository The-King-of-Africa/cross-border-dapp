const fs = require('fs');
const path = require('path');

const artifactPath = path.join(__dirname, '..', 'artifacts', 'contracts', 'CrossBorderPayments.sol', 'CrossBorderPayments.json');
const outputPath = path.join(__dirname, '..', 'contracts', 'CrossBorderPayments.abi.json');

if (!fs.existsSync(artifactPath)) {
  throw new Error('Artifact not found. Run `npm run compile` first.');
}

const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
fs.writeFileSync(outputPath, JSON.stringify(artifact.abi, null, 2) + '\n');
console.log(`ABI exported to ${outputPath}`);
