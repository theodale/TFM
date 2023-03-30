const { ethers } = require("hardhat");

const main = async () => {
  const owner = await ethers.getSigner();

  console.log("DEPLOYING TRUFIN PROTOCOL:");
  console.log("Deployer:", owner.address);

  // Deploy Utils library
  const UtilsFactory = await ethers.getContractFactory("Utils");
  const Utils = await UtilsFactory.deploy();

  console.log("Utils: ", Utils.address);

  // Deploy CollateralManager
  const CollateralManagerFactory = await ethers.getContractFactory(
    "CollateralManager"
  );
  const CollateralManager = await upgrades.deployProxy(
    CollateralManagerFactory,
    [owner.address, owner.address],
    {
      kind: "uups",
    }
  );

  console.log("CollateralManager: ", CollateralManager.address);

  // Deploy TFM
  const TFMFactory = await ethers.getContractFactory("TFM", {
    libraries: {
      Utils: Utils.address,
    },
  });
  const TFM = await upgrades.deployProxy(
    TFMFactory,
    [CollateralManager.address, owner.address, owner.address, owner.address],
    {
      unsafeAllowLinkedLibraries: true,
      kind: "uups",
    }
  );

  console.log("TFM: ", TFM.address);
  console.log(
    "Verify TFM: ",
    "npx hardhat verify --network mumbai ",
    TFM.address
  );

  await CollateralManager.setTFM(TFM.address);

  const MockERC20Factory = await ethers.getContractFactory("MockERC20");

  const Basis = await MockERC20Factory.deploy();

  console.log("Basis: ", Basis.address);

  // npx hardhat verify --network mumbai address
};

main();
