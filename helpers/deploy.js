const { ethers, upgrades } = require("hardhat");

const deploy = async (owner) => {
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
    [owner.address, owner.address]
  );

  const TFM = await upgrades.deployProxy(
    TFMFactory,
    [CollateralManager.address, owner.address, owner.address, owner.address],
    {
      unsafeAllowLinkedLibraries: true,
      kind: "uups",
    }
  );

  await CollateralManager.setTFM(TFM.address);

  const MockERC20Factory = await ethers.getContractFactory("MockERC20");
  const MockERC20 = await MockERC20Factory.deploy();

  return {
    TFM,
    CollateralManager,
    MockERC20,
    Utils,
  };
};

module.exports = {
  deploy,
};
