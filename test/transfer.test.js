const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { freshDeployment } = require("../helpers/fixtures.js");
const { spearmint } = require("../helpers/actions/spearmint.js");
const { transfer } = require("../helpers/actions/transfer.js");
const { STRATEGY, SPEARMINT, TRANSFER } = require("./test-parameters.js");

describe("TRANSFER", () => {
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
      carol: this.carol,
    } = await loadFixture(freshDeployment));
  });

  // This block describes an alpha transfer => omega transfer is tested later
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

      this.transferTransaction = await transfer(
        this.TFM,
        this.CollateralManager,
        this.Basis,
        this.strategyId,
        this.oracle,
        TRANSFER.recipientCollateralRequirement,
        TRANSFER.recipientFee,
        TRANSFER.senderFee,
        TRANSFER.premium,
        this.alice,
        this.carol,
        this.bob
      );
    });

    it("Updates transferred position minted strategy has correct state", async () => {
      const strategy = await this.TFM.getStrategy(this.strategyId);

      expect(strategy.alpha).to.equal(this.carol.address);
    });
  });
});
