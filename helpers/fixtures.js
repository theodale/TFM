const { ethers, upgrades } = require("hardhat");

async function testDeployment() {
  const [owner, oracle, alice, bob] = await ethers.getSigners();

  // Deploy Utils library
  const UtilsFactory = await ethers.getContractFactory("Utils");
  const Utils = await UtilsFactory.deploy();

  // Logic contract factories
  const TFMFactory = await ethers.getContractFactory("TFM", {
    libraries: {
      Utils: Utils.address,
    },
  });
  const CollateralManagerFactory = await ethers.getContractFactory(
    "CollateralManager"
  );

  // Deploy proxies and implementation contracts
  const CollateralManager = await upgrades.deployProxy(
    CollateralManagerFactory,
    [owner.address, owner.address],
    {
      kind: "uups",
    }
  );

  const TFM = await upgrades.deployProxy(
    TFMFactory,
    [CollateralManager.address, owner.address, owner.address, oracle.address],
    {
      unsafeAllowLinkedLibraries: true,
      kind: "uups",
    }
  );

  await CollateralManager.setTFM(TFM.address);

  const MockERC20Factory = await ethers.getContractFactory("MockERC20");

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
  };
}

module.exports = {
  testDeployment,
};
