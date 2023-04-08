const { ethers, upgrades } = require("hardhat");

// Deploys a fresh set of protocol contracts for use in testing
async function freshDeployment() {
  const [owner, oracle, alice, bob, carol, liquidator, treasury] =
    await ethers.getSigners();

  // Deploy Utils library
  const UtilsFactory = await ethers.getContractFactory("Utils");
  const Utils = await UtilsFactory.deploy();

  const Wallet = await ethers.getContractFactory("Wallet");
  const WalletImplementation = await Wallet.deploy();

  // Deploy CollateralManager
  const CollateralManagerFactory = await ethers.getContractFactory(
    "CollateralManager"
  );
  const CollateralManager = await upgrades.deployProxy(
    CollateralManagerFactory,
    [treasury.address, owner.address, WalletImplementation.address],
    {
      kind: "uups",
    }
  );

  // Deploy TFM
  const TFMFactory = await ethers.getContractFactory("TFM", {
    libraries: {
      Utils: Utils.address,
    },
  });
  const TFM = await upgrades.deployProxy(
    TFMFactory,
    [
      CollateralManager.address,
      owner.address,
      liquidator.address,
      oracle.address,
      3600,
    ],
    {
      unsafeAllowLinkedLibraries: true,
      kind: "uups",
    }
  );

  await CollateralManager.setTFM(TFM.address);

  const MockERC20Factory = await ethers.getContractFactory("MockERC20");

  // Deploy mock tokens
  const BRA = await MockERC20Factory.deploy();
  const KET = await MockERC20Factory.deploy();
  const Basis = await MockERC20Factory.deploy();

  return {
    TFM,
    CollateralManager,
    BRA,
    KET,
    Basis,
    Utils,
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
