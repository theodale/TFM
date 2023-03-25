const { expect } = require("chai");
const { ethers } = require("hardhat");
const { testDeploy } = require("../helpers/deploy.js");
const { mintAndDeposit } = require("../helpers/collateral-management.js");
const { spearmint } = require("../helpers/actions.js");
const { generateExerciseTerms } = require("../helpers/terms.js");

describe("EXERCISE", () => {
  before(async () => {
    // Owner is oracle and treasury
    [this.owner, this.alice, this.bob] = await ethers.getSigners();
  });

  beforeEach(async () => {
    ({
      TFM: this.TFM,
      CollateralManager: this.CollateralManager,
      BRA: this.BRA,
      KET: this.KET,
      Basis: this.Basis,
      Utils: this.Utils,
    } = await testDeploy(this.owner));

    // TEST PARAMETERS
    this.alphaDeposit = ethers.utils.parseEther("10");
    this.omegaDeposit = ethers.utils.parseEther("10");
    this.expiry = 1680000000;
    this.alphaCollateralRequirement = ethers.utils.parseEther("1");
    this.omegaCollateralRequirement = ethers.utils.parseEther("1");
    this.alphaFee = ethers.utils.parseEther("0.01");
    this.omegaFee = ethers.utils.parseEther("0.01");
    this.amplitude = ethers.utils.parseEther("10");
    this.phase = [
      [ethers.utils.parseEther("1"), ethers.BigNumber.from("500000")],
    ];
    this.premium = ethers.utils.parseEther("0.01");
    this.transferable = true;
    this.payout = ethers.utils.parseEther("0.5");

    // Give unallocated collateral in this.basis to alice and bob
    await mintAndDeposit(
      this.CollateralManager,
      this.Basis,
      this.alice,
      this.alphaDeposit
    );
    await mintAndDeposit(
      this.CollateralManager,
      this.Basis,
      this.bob,
      this.omegaDeposit
    );

    this.strategyId = await spearmint(
      this.alice,
      this.bob,
      this.premium,
      this.transferable,
      this.TFM,
      this.owner,
      this.expiry,
      this.BRA,
      this.KET,
      this.Basis,
      this.amplitude,
      this.phase,
      this.alphaCollateralRequirement,
      this.omegaCollateralRequirement,
      this.alphaFee,
      this.omegaFee
    );
  });

  it("exercise", async () => {
    const { exerciseTerms, oracleSignature } = await generateExerciseTerms(
      this.TFM,
      this.owner,
      this.payout,
      this.alphaFee,
      this.omegaFee,
      this.expiry,
      this.BRA,
      this.KET,
      this.Basis,
      this.amplitude,
      this.phase
    );

    const exerciseParameters = {
      oracleSignature: oracleSignature,
      strategyId: this.strategyId,
    };

    await this.TFM.exercise(exerciseTerms, exerciseParameters);
  });
});
