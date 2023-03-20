const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  deploy,
  signSpearmintParameters,
  generateSpearmintDataPackage,
} = require("./test-utils");

describe("Spearmint", () => {
  before(async () => {
    [this.owner, this.alice, this.bob] = await ethers.getSigners();

    ({
      TFM: this.TFM,
      CollateralManager: this.collateralManager,
      MockERC20: this.basis,
    } = await deploy(this.owner));
  });

  it("Spearmint", async () => {
    await this.basis.mint(this.alice.address, 1000000);
    await this.basis.mint(this.bob.address, 1000000);

    await this.basis
      .connect(this.alice)
      .approve(this.collateralManager.address, 1000000);
    await this.basis
      .connect(this.bob)
      .approve(this.collateralManager.address, 1000000);

    await this.collateralManager
      .connect(this.alice)
      .deposit(this.basis.address, 1000000);
    await this.collateralManager
      .connect(this.bob)
      .deposit(this.basis.address, 1000000);

    const { trufinOracleSignature, spearmintDataPackage } =
      await generateSpearmintDataPackage(
        this.owner,
        1000000,
        100,
        200,
        100,
        100,
        0,
        ethers.constants.AddressZero,
        ethers.constants.AddressZero,
        this.basis.address,
        400,
        [
          [300, 200],
          [-300, 123],
        ]
      );

    const { spearmintSignature: aliceSignature, spearmintParameters } =
      await signSpearmintParameters(
        this.alice,
        trufinOracleSignature,
        this.alice.address,
        this.bob.address,
        400,
        true,
        0
      );

    const { spearmintSignature: bobSignature } = await signSpearmintParameters(
      this.bob,
      trufinOracleSignature,
      this.alice.address,
      this.bob.address,
      400,
      true,
      0
    );

    await this.TFM.spearmint(
      spearmintDataPackage,
      spearmintParameters,
      aliceSignature,
      bobSignature
    );
  });
});
