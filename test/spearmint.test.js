const { expect } = require("chai");
const { ethers } = require("hardhat");
const { deploy } = require("../helpers/deploy.js");
const { generateSpearmintDataPackage } = require("../helpers/data-packages.js");
const { signSpearmintParameters } = require("../helpers/meta-transactions.js");
const { mintAndDeposit } = require("../helpers/collateral-management.js");
const { spearmint } = require("../helpers/actions.js");

describe("Spearmint", () => {
  before(async () => {
    [this.owner, this.alice, this.bob] = await ethers.getSigners();
  });

  beforeEach(async () => {
    ({
      TFM: this.TFM,
      CollateralManager: this.collateralManager,
      MockERC20: this.basis,
    } = await deploy(this.owner));
  });

  describe("Access Control", () => {
    it("should mint and deposit", async () => {});

    it("should mint and deposit", async () => {});

    it("should mint and deposit", async () => {});
  });

  it("First spearmint test", async () => {
    // await mintAndDeposit(
    //   this.collateralManager,
    //   this.basis,
    //   this.alice,
    //   ethers.utils.parseEther("1")
    // );
    // await mintAndDeposit(
    //   this.collateralManager,
    //   this.basis,
    //   this.bob,
    //   ethers.utils.parseEther("1")
    // );
    // const strategyId = await spearmint(
    //   this.alice,
    //   this.bob,
    //   1000,
    //   true,
    //   this.TFM,
    //   this.owner,
    //   10000000,
    //   ethers.constants.AddressZero,
    //   ethers.constants.AddressZero,
    //   this.basis.address,
    //   1000,
    //   [[1234, 5678]],
    //   100,
    //   100,
    //   10,
    //   10
    // );
  });

  it("Sencond spearmint test", async () => {});
});
