const { ethers, upgrades } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

async function zeroState() {
  [owner, alice, bob] = await ethers.getSigners();
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
    [CollateralManager.address, owner.address, owner.address, owner.address],
    {
      unsafeAllowLinkedLibraries: true,
      kind: "uups",
    }
  );

  await CollateralManager.setTFM(TFM.address);

  const MockERC20Factory = await ethers.getContractFactory("MockERC20");
  const MockERC20 = await MockERC20Factory.deploy();
  await MockERC20.mint(alice, 100000000);
  await MockERC20.mint(bob, 100000000);

  return {
    TFM,
    CollateralManager,
    MockERC20,
    Utils,
    owner,
    alice,
    bob,
  };
}

async function depositState() {
  const { TFM, CollateralManager, MockERC20, Utils, owner, alice, bob } =
    await loadFixture(zeroState);
  await MockERC20.connect(alice).approve(CollateralManager, 100000000);
  await MockERC20.connect(bob).approve(CollateralManager, 100000000);
  await CollateralManager.connect(alice).deposit(MockERC20.address, 100000000);
  await CollateralManager.connect(bob).deposit(MockERC20.address, 100000000);
  return {
    TFM,
    CollateralManager,
    MockERC20,
    Utils,
    owner,
    alice,
    bob,
  };
}
