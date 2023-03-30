const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { freshDeployment } = require("../helpers/fixtures.js");
const { spearmint } = require("../helpers/actions/spearmint.js");
const { liquidate } = require("../helpers/actions/liquidate.js");
const {
  STRATEGY_ONE,
  SPEARMINT_ONE,
  LIQUIDATION_ONE,
} = require("./test-parameters.js");

describe("LIQUIDATION", () => {
  beforeEach(async () => {
    ({
      TFM: this.TFM,
      CollateralManager: this.CollateralManager,
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
        this.CollateralManager,
        this.oracle,
        this.BRA,
        this.KET,
        this.Basis,
        SPEARMINT_ONE.premium,
        STRATEGY_ONE.transferable,
        STRATEGY_ONE.expiry,
        STRATEGY_ONE.amplitude,
        STRATEGY_ONE.phase,
        SPEARMINT_ONE.alphaCollateralRequirement,
        SPEARMINT_ONE.omegaCollateralRequirement,
        SPEARMINT_ONE.alphaFee,
        SPEARMINT_ONE.omegaFee
      ));

      this.liquidateTransaction = await liquidate(
        this.TFM,
        this.CollateralManager,
        this.oracle,
        this.liquidator,
        this.strategyId,
        LIQUIDATION_ONE.compensation,
        LIQUIDATION_ONE.alphaFee,
        LIQUIDATION_ONE.omegaFee,
        LIQUIDATION_ONE.postLiquidationAmplitude
      );
    });

    it("Emits 'Liquidated' event with correct parameters", async () => {
      expect(this.liquidateTransaction)
        .to.emit(this.TFM, "Liquidated")
        .withArgs(this.strategyId);
    });

    it("Amplitude reduced to correct value", async () => {
      const strategy = await this.TFM.getStrategy(this.strategyId);

      expect(strategy.amplitude).to.equal(
        LIQUIDATION_ONE.postLiquidationAmplitude
      );
    });

    it("Fees sent to treasury", async () => {
      await expect(this.liquidateTransaction).to.changeTokenBalance(
        this.Basis,
        this.treasury,
        LIQUIDATION_ONE.alphaFee.add(LIQUIDATION_ONE.omegaFee)
      );
    });

    it("Compensation transferred between parties", async () => {
      const alphaPersonalPoolAddress =
        await this.CollateralManager.personalPools(this.alice.address);
      const omegaPersonalPoolAddress =
        await this.CollateralManager.personalPools(this.bob.address);

      await expect(this.liquidateTransaction).to.changeTokenBalances(
        this.Basis,
        [alphaPersonalPoolAddress, omegaPersonalPoolAddress],
        [
          LIQUIDATION_ONE.compensation.mul(-1).sub(LIQUIDATION_ONE.alphaFee),
          LIQUIDATION_ONE.compensation.sub(LIQUIDATION_ONE.omegaFee),
        ]
      );
    });
  });
});
