import { ethers } from "hardhat";

async function main() {
  // Get the ContractFactory for our main contract
  const FreelanceMarketplace = await ethers.getContractFactory("FreelanceMarketplace");

  // Start the deployment process
  console.log("Deploying FreelanceMarketplace contract...");
  const marketplace = await FreelanceMarketplace.deploy();

  // Wait for the deployment to be confirmed on the network
  await marketplace.deployed();

  // Log the address of the newly deployed contract
  console.log("FreelanceMarketplace deployed to:", marketplace.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
