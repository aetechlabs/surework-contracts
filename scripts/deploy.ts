import { ethers } from "hardhat";

async function main() {
  console.log("Deploying SureWork Escrow Contract...");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "ETH");

  // Fee collector address (can be updated later via contract)
  const feeCollector = process.env.FEE_COLLECTOR_ADDRESS || deployer.address;
  console.log("Fee collector:", feeCollector);

  const SureWorkEscrow = await ethers.getContractFactory("SureWorkEscrow");
  const escrow = await SureWorkEscrow.deploy(feeCollector);

  await escrow.waitForDeployment();
  const escrowAddress = await escrow.getAddress();

  console.log("✅ SureWorkEscrow deployed to:", escrowAddress);
  console.log("\nSave this contract address for backend integration!");

  // Verification instructions
  console.log("\n📝 To verify on block explorer:");
  console.log(`npx hardhat verify --network <network> ${escrowAddress} ${feeCollector}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
