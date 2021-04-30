// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const Potluck = await hre.ethers.getContractFactory("Potluck");

  // Deploy potluck
  // FILL THESE VALUES IN
  const potluck = await Potluck.deploy(
    "0xdbdb4d16eda451d0503b854cf79d55697f90c8df", // ERC20 token address
    hre.ethers.utils.parseEther("10"), // ETH funding limit
    Math.floor(Date.now() / 1000) + 86400 // Funding deadline
  );

  await potluck.deployed();

  console.log("Potluck deployed to:", potluck.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
