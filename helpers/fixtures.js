const { ethers, upgrades } = require("hardhat");

// Deploys and initialises a fresh protocol
async function freshDeployment() {
  const [owner, oracle, alice, bob, carol, liquidator, treasury] =
    await ethers.getSigners();

  // Deploy Validator library
  const ValidatorFactory = await ethers.getContractFactory("Validator");
  const Validator = await ValidatorFactory.deploy();

  // Deploy TrufinWallet implementation
  const TrufinWalletFactory = await ethers.getContractFactory("TrufinWallet");
  const TrufinWalletImplementation = await TrufinWalletFactory.deploy();

  // Deploy AssetLayer
  const AssetLayerFactory = await ethers.getContractFactory("AssetLayer");
  const AssetLayer = await upgrades.deployProxy(
    AssetLayerFactory,
    [treasury.address, owner.address, TrufinWalletImplementation.address],
    {
      kind: "uups",
    }
  );

  // Deploy ActionLayer
  const ActionLayerFactory = await ethers.getContractFactory("ActionLayer", {
    libraries: {
      Validator: Validator.address,
    },
  });
  const ActionLayer = await upgrades.deployProxy(
    ActionLayerFactory,
    [
      owner.address,
      liquidator.address,
      oracle.address,
      3600,
      AssetLayer.address,
    ],
    {
      unsafeAllowLinkedLibraries: true,
      kind: "uups",
    }
  );

  // Link AssetLayer to ActionLayer
  await AssetLayer.setActionLayer(ActionLayer.address);

  const MockERC20Factory = await ethers.getContractFactory("MockERC20");

  // Deploy mock ERC20 tokens
  const BRA = await MockERC20Factory.deploy();
  const KET = await MockERC20Factory.deploy();
  const Basis = await MockERC20Factory.deploy();

  return {
    ActionLayer,
    AssetLayer,
    BRA,
    KET,
    Basis,
    Validator,
    owner,
    oracle,
    alice,
    bob,
    carol,
    liquidator,
    treasury,
  };
}

module.exports = {
  freshDeployment,
};
