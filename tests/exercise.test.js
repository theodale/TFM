const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { freshDeployment } = require("../helpers/fixtures.js");
const { spearmint } = require("../helpers/actions/spearmint.js");
const { exercise } = require("../helpers/actions/exercise.js");
const {
  checkReserves,
  checkWalletBalanceChanges,
} = require("../helpers/assertions.js");
const { STRATEGY, MINT, EXERCISE } = require("./PARAMETERS.js");

describe("EXERCISE", () => {
  beforeEach(async () => {
    ({
      ActionLayer: this.ActionLayer,
      AssetLayer: this.AssetLayer,
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

      this.exerciseTransaction = await exercise(
        this.ActionLayer,
        this.strategyId,
        this.oracle,
        EXERCISE.payout
      );
    });

    it("Exercised strategy deleted", async () => {
      const strategy = await this.ActionLayer.getStrategy(this.strategyId);

      expect(strategy.expiry).to.equal(0);
      expect(strategy.amplitude).to.equal(0);
      expect(strategy.transferable).to.equal(false);
      expect(strategy.alpha).to.equal(ethers.constants.AddressZero);
      expect(strategy.omega).to.equal(ethers.constants.AddressZero);
      expect(strategy.bra).to.equal(ethers.constants.AddressZero);
      expect(strategy.ket).to.equal(ethers.constants.AddressZero);
      expect(strategy.basis).to.equal(ethers.constants.AddressZero);
      expect(strategy.phase).to.deep.equal([]);
    });

    it("Correct post-exercise reserve balances", async () => {
      await checkReserves(
        this.AssetLayer,
        this.Basis,
        [this.alice, this.bob],
        [
          MINT.alphaCollateralRequirement.sub(EXERCISE.payout),
          MINT.omegaCollateralRequirement.add(EXERCISE.payout),
        ]
      );
    });

    it("Emits 'Exercise' event with correct parameters", async () => {
      await expect(this.exerciseTransaction)
        .to.emit(this.ActionLayer, "Exercise")
        .withArgs(this.strategyId);
    });

    it("Payout transferred between wallets", async () => {
      await checkWalletBalanceChanges(
        this.AssetLayer,
        this.Basis,
        [this.alice, this.bob],
        [EXERCISE.payout.mul(-1), EXERCISE.payout],
        this.exerciseTransaction
      );
    });
  });
});
