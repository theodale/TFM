const { ethers, upgrades } = require("hardhat");

// Deploys a fresh set of protocol contracts for use in testing
async function freshDeployment() {
  const [owner, oracle, alice, bob, carol, liquidator, treasury] =
    await ethers.getSigners();

  // Deploy Validator library
  const ValidatorFactory = await ethers.getContractFactory("Validator");
  const Validator = await ValidatorFactory.deploy();

  const Wallet = await ethers.getContractFactory("TrufinWallet");
  const WalletImplementation = await Wallet.deploy();

  // Deploy FundManager
  const FundManagerFactory = await ethers.getContractFactory("AssetLayer");
  const FundManager = await upgrades.deployProxy(
    FundManagerFactory,
    [treasury.address, owner.address, WalletImplementation.address],
    {
      kind: "uups",
    }
  );

  // Deploy TFM
  const TFMFactory = await ethers.getContractFactory("ActionLayer", {
    libraries: {
      Validator: Validator.address,
    },
  });
  const TFM = await upgrades.deployProxy(
    TFMFactory,
    [
      owner.address,
      liquidator.address,
      oracle.address,
      3600,
      FundManager.address,
    ],
    {
      unsafeAllowLinkedLibraries: true,
      kind: "uups",
    }
  );

  // Link manager to TFM
  await FundManager.setTFM(TFM.address);

  const MockERC20Factory = await ethers.getContractFactory("MockERC20");

  // Deploy mock tokens
  const BRA = await MockERC20Factory.deploy();
  const KET = await MockERC20Factory.deploy();
  const Basis = await MockERC20Factory.deploy();

  return {
    TFM,
    FundManager,
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
