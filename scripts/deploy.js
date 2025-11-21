const { ethers } = require("hardhat");

async function main() {
  const NFTversePortal = await ethers.getContractFactory("NFTversePortal");
  const nFTversePortal = await NFTversePortal.deploy();

  await nFTversePortal.deployed();

  console.log("NFTversePortal contract deployed to:", nFTversePortal.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
