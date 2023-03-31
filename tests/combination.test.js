const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { freshDeployment } = require("../helpers/fixtures.js");
const { spearmint } = require("../helpers/actions/spearmint.js");
const { combine } = require("../helpers/actions/combine.js");
const { STRATEGY, SPEARMINT, COMBINATION } = require("./test-parameters.js");

describe("COMBINATION", () => {
  beforeEach(async () => {
    ({
      TFM: this.TFM,
      CollateralManager: this.CollateralManager,
      BRA: this.BRA,
      KET: this.KET,
      Basis: this.Basis,
      Utils: this.Utils,
      oracle: this.oracle,
      treasury: this.treasury,
      owner: this.owner,
      alice: this.alice,
      bob: this.bob,
    } = await loadFixture(freshDeployment));
  });

  describe("Successful Call", () => {
    beforeEach(async () => {
      ({ strategyId: this.strategyOneId } = await spearmint(
        this.alice,
        this.bob,
        this.TFM,
        this.CollateralManager,
        this.oracle,
        this.BRA,
        this.KET,
        this.Basis,
        SPEARMINT.premium,
        STRATEGY.transferable,
        STRATEGY.expiry,
        STRATEGY.amplitude,
        STRATEGY.phase,
        SPEARMINT.alphaCollateralRequirement,
        SPEARMINT.omegaCollateralRequirement,
        SPEARMINT.alphaFee,
        SPEARMINT.omegaFee
      ));

      ({ strategyId: this.strategyTwoId } = await spearmint(
        this.alice,
        this.bob,
        this.TFM,
        this.CollateralManager,
        this.oracle,
        this.BRA,
        this.KET,
        this.Basis,
        SPEARMINT.premium,
        STRATEGY.transferable,
        STRATEGY.expiry,
        STRATEGY.amplitude,
        STRATEGY.phase,
        SPEARMINT.alphaCollateralRequirement,
        SPEARMINT.omegaCollateralRequirement,
        SPEARMINT.alphaFee,
        SPEARMINT.omegaFee
      ));

      this.combinationTransaction = await combine(
        this.TFM,
        this.CollateralManager,
        this.Basis,
        this.strategyOneId,
        this.strategyTwoId,
        this.alice,
        this.bob,
        this.oracle,
        COMBINATION.strategyOneAlphaFee,
        COMBINATION.strategyOneOmegaFee,
        COMBINATION.resultingAlphaCollateralRequirement,
        COMBINATION.resultingOmegaCollateralRequirement,
        COMBINATION.resultingPhase,
        COMBINATION.resultingAmplitude
      );
    });

    it("Strategy one updated to combination state", async () => {
      const combinationStrategy = await this.TFM.getStrategy(
        this.strategyOneId
      );

      expect(combinationStrategy.phase).to.deep.equal(
        COMBINATION.resultingPhase
      );
      expect(combinationStrategy.amplitude).to.equal(
        COMBINATION.resultingAmplitude
      );
    });

    it("Post-combination collateral balances (allocated/unallocated) are correct", async () => {
      // asd
    });

    it("Strategy two deleted", async () => {
      const deletedStrategy = await this.TFM.getStrategy(this.strategyTwoId);
    });

    it("Emits 'Combine' event with correct parameters", async () => {
      await expect(this.combinationTransaction)
        .to.emit(this.TFM, "Combination")
        .withArgs(this.strategyOneId, this.strategyTwoId);
    });
  });
});
