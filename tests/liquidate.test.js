const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { freshDeployment } = require("../helpers/fixtures.js");
const { spearmint } = require("../helpers/actions/spearmint.js");
const { liquidate } = require("../helpers/actions/liquidate.js");
const { STRATEGY, MINT, LIQUIDATION } = require("./PARAMETERS.js");

describe("LIQUIDATION", () => {
  beforeEach(async () => {
    ({
      TFM: this.TFM,
      FundManager: this.FundManager,
      BRA: this.BRA,
      KET: this.KET,
      Basis: this.Basis,
      Utils: this.Utils,
      oracle: this.oracle,
      liquidator: this.liquidator,
      owner: this.owner,
      treasury: this.treasury,
      alice: this.alice,
      bob: this.bob,
    } = await loadFixture(freshDeployment));
  });

  describe("Successful Call", () => {
    beforeEach(async () => {
      ({
        strategyId: this.strategyId,
        spearmintTransaction: this.spearmintTransaction,
      } = await spearmint(
        this.alice,
        this.bob,
        this.TFM,
        this.FundManager,
        this.oracle,
        this.BRA,
        this.KET,
        this.Basis,
        MINT.premium,
        STRATEGY.transferable,
        STRATEGY.expiry,
        STRATEGY.amplitude,
        STRATEGY.phase,
        MINT.alphaCollateralRequirement,
        MINT.omegaCollateralRequirement,
        MINT.alphaFee,
        MINT.omegaFee
      ));

      this.liquidateTransaction = await liquidate(
        this.TFM,
        this.FundManager,
        this.oracle,
        this.liquidator,
        this.strategyId,
        LIQUIDATION.compensation,
        LIQUIDATION.alphaFee,
        LIQUIDATION.omegaFee,
        LIQUIDATION.postLiquidationAmplitude
      );
    });

    it("Emits 'Liquidated' event with correct parameters", async () => {
      expect(this.liquidateTransaction)
        .to.emit(this.TFM, "Liquidation")
        .withArgs(this.strategyId);
    });

    it("Amplitude reduced to correct value", async () => {
      const strategy = await this.TFM.getStrategy(this.strategyId);

      expect(strategy.amplitude).to.equal(LIQUIDATION.postLiquidationAmplitude);
    });

    it("Fees sent to treasury", async () => {
      await expect(this.liquidateTransaction).to.changeTokenBalance(
        this.Basis,
        this.treasury,
        LIQUIDATION.alphaFee.add(LIQUIDATION.omegaFee)
      );
    });

    // it("Compensation and fees taken from personal pools", async () => {
    //   await checkPoolBalanceChanges(
    //     this.FundManager,
    //     this.Basis,
    //     [this.alice, this.bob],
    //     [
    //       LIQUIDATION.compensation.mul(-1).sub(LIQUIDATION.alphaFee),
    //       LIQUIDATION.compensation.sub(LIQUIDATION.omegaFee),
    //     ],
    //     this.liquidateTransaction
    //   );
    // });

    // it("Correct post-liquidation strategy collateral allocations", async () => {
    //   // This will not working if compensation is -ve
    //   await checkCollateralAllocations(
    //     this.FundManager,
    //     this.strategyId,
    //     [this.alice, this.bob],
    //     [
    //       MINT.alphaCollateralRequirement
    //         .sub(LIQUIDATION.alphaFee)
    //         .sub(LIQUIDATION.compensation),
    //       MINT.omegaCollateralRequirement.sub(LIQUIDATION.omegaFee),
    //     ]
    //   );
    // });

    // it("Correct post-liquidation unallocated collateral balances", async () => {
    //   // Also only works for +ve compensation
    //   await checkUnallocatedCollateralBalances(
    //     this.FundManager,
    //     this.Basis,
    //     [this.bob],
    //     [LIQUIDATION.compensation]
    //   );
    // });
  });
});
