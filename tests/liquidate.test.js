const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { freshDeployment } = require("../helpers/fixtures.js");
const { spearmint } = require("../helpers/actions/spearmint.js");
const { liquidate } = require("../helpers/actions/liquidate.js");
const {
  checkAllocations,
  checkReserves,
  checkWalletBalanceChanges,
} = require("../helpers/assertions.js");
const { STRATEGY, MINT, LIQUIDATION } = require("./PARAMETERS.js");

describe("LIQUIDATION", () => {
  beforeEach(async () => {
    ({
      ActionLayer: this.ActionLayer,
      AssetLayer: this.AssetLayer,
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
        this.ActionLayer,
        this.AssetLayer,
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
        this.ActionLayer,
        this.AssetLayer,
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
        .to.emit(this.ActionLayer, "Liquidation")
        .withArgs(this.strategyId);
    });

    it("Amplitude reduced to correct value", async () => {
      const strategy = await this.ActionLayer.getStrategy(this.strategyId);

      expect(strategy.amplitude).to.equal(LIQUIDATION.postLiquidationAmplitude);
    });

    it("Fees sent to treasury", async () => {
      await expect(this.liquidateTransaction).to.changeTokenBalance(
        this.Basis,
        this.treasury,
        LIQUIDATION.alphaFee.add(LIQUIDATION.omegaFee)
      );
    });

    it("Compensation and fees taken from wallets", async () => {
      await checkWalletBalanceChanges(
        this.AssetLayer,
        this.Basis,
        [this.alice, this.bob],
        [
          LIQUIDATION.compensation.mul(-1).sub(LIQUIDATION.alphaFee),
          LIQUIDATION.compensation.sub(LIQUIDATION.omegaFee),
        ],
        this.liquidateTransaction
      );
    });

    it("Correct post-liquidation strategy collateral allocations", async () => {
      // This will not working if compensation is -ve
      await checkAllocations(
        this.AssetLayer,
        this.strategyId,
        [this.alice, this.bob],
        [
          {
            alphaBalance: MINT.alphaCollateralRequirement
              .sub(LIQUIDATION.alphaFee)
              .sub(LIQUIDATION.compensation),
            omegaBalance: 0,
          },
          {
            alphaBalance: 0,
            omegaBalance: MINT.omegaCollateralRequirement.sub(
              LIQUIDATION.omegaFee
            ),
          },
        ]
      );
    });

    it("Correct post-liquidation reserve balances", async () => {
      // Also only works for +ve compensation
      await checkReserves(
        this.AssetLayer,
        this.Basis,
        [this.bob],
        [LIQUIDATION.compensation]
      );
    });
  });
});
