const { ethers } = require("hardhat");

const main = async () => {
  const owner = await ethers.getSigner();

  console.log("DEPLOYING THE FIELD MACHINE:");
  console.log("Deployer:", owner.address);

  // Deploy Validator library
  const ValidatorFactory = await ethers.getContractFactory("Validator");
  const Validator = await ValidatorFactory.deploy();

  console.log("Validator: ", Validator.address);

  const TrufinWallet = await ethers.getContractFactory("TrufinWallet");
  const TrufinWalletImplementation = await TrufinWallet.deploy();

  console.log(
    "TrufinWallet Implementation: ",
    TrufinWalletImplementation.address
  );

  // Deploy AssetLayer
  const AssetLayerFactory = await ethers.getContractFactory("AssetLayer");
  const AssetLayer = await upgrades.deployProxy(
    AssetLayerFactory,
    [owner.address, owner.address, TrufinWalletImplementation.address],
    {
      kind: "uups",
    }
  );
  console.log("AssetLayer: ", AssetLayer.address);
  console.log(
    "Verify AssetLayer: ",
    "npx hardhat verify --network mumbai ",
    AssetLayer.address
  );

  // Deploy ActionLayer
  const ActionLayerFactory = await ethers.getContractFactory("ActionLayer", {
    libraries: {
      Validator: Validator.address,
    },
  });
  const ActionLayer = await upgrades.deployProxy(
    ActionLayerFactory,
    [owner.address, owner.address, owner.address, 3600, AssetLayer.address],
    {
      unsafeAllowLinkedLibraries: true,
      kind: "uups",
    }
  );

  console.log("ActionLayer: ", ActionLayer.address);
  console.log(
    "Verify ActionLayer: ",
    "npx hardhat verify --network mumbai ",
    ActionLayer.address
  );

  await AssetLayer.setActionLayer(ActionLayer.address);

  const MockERC20Factory = await ethers.getContractFactory("MockERC20");
  const Basis = await MockERC20Factory.deploy();

  console.log("Basis: ", Basis.address);
};

main();
