const hre = require('hardhat');
require('dotenv').config();

async function main() {
  const feeBasisPoints = Number(process.env.FEE_BASIS_POINTS || '50');
  const minimumInvestment = process.env.MINIMUM_INVESTMENT || '1000000000000000';
  const treasuryAddress = process.env.TREASURY_ADDRESS || hre.ethers.ZeroAddress;

  const [deployer] = await hre.ethers.getSigners();
  console.log(`Deploying from: ${deployer.address}`);

  const Factory = await hre.ethers.getContractFactory('CrossBorderPayments');
  const contract = await Factory.deploy(
    feeBasisPoints,
    treasuryAddress,
    minimumInvestment
  );

  await contract.waitForDeployment();
  const address = await contract.getAddress();

  console.log(`CrossBorderPayments deployed to: ${address}`);
  console.log(`Fee basis points: ${feeBasisPoints}`);
  console.log(`Treasury: ${treasuryAddress === hre.ethers.ZeroAddress ? deployer.address : treasuryAddress}`);
  console.log(`Minimum investment (wei): ${minimumInvestment}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
