const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { freshDeployment } = require("../helpers/fixtures.js");
const { spearmint } = require("../helpers/actions/spearmint.js");
const { STRATEGY_ONE, SPEARMINT_ONE } = require("./test-parameters.js");

describe("SPEARMINT", () => {
  beforeEach(async () => {
    ({
      TFM: this.TFM,
      CollateralManager: this.CollateralManager,
      BRA: this.BRA,
      KET: this.KET,
      Basis: this.Basis,
      Utils: this.Utils,
      oracle: this.oracle,
      owner: this.owner,
      alice: this.alice,
      bob: this.bob,
    } = await loadFixture(freshDeployment));
  });

  describe("Basic Spearmint Call", () => {
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
    });
  });
});
