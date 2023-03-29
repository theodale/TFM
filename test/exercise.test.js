const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { freshDeployment } = require("../helpers/fixtures.js");
const { spearmint } = require("../helpers/actions/spearmint.js");
const { exercise } = require("../helpers/actions/exercise.js");
const {
  STRATEGY_ONE,
  SPEARMINT_ONE,
  EXERCISE_ONE,
} = require("./test-parameters.js");

describe("EXERCISE", () => {
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

  describe("Basic Exercise Call", () => {
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

      this.exerciseTransaction = await exercise(
        this.TFM,
        this.CollateralManager,
        this.Basis,
        this.strategyId,
        this.alice,
        this.bob,
        this.oracle,
        EXERCISE_ONE.payout,
        EXERCISE_ONE.alphaFee,
        EXERCISE_ONE.omegaFee
      );
    });

    it("Exercised strategy's state deleted", async () => {
      const strategy = await this.TFM.getStrategy(this.strategyId);

      expect(strategy.expiry).to.equal(0);
      expect(strategy.amplitude).to.equal(0);
      expect(strategy.transferable).to.equal(false);
      expect(strategy.alpha).to.equal(ethers.constants.AddressZero);
      expect(strategy.omega).to.equal(ethers.constants.AddressZero);
      expect(strategy.bra).to.equal(ethers.constants.AddressZero);
      expect(strategy.ket).to.equal(ethers.constants.AddressZero);
      expect(strategy.basis).to.equal(ethers.constants.AddressZero);
      expect(strategy.phase).to.deep.equal([]);

      // Check allocations are zero?
    });

    it("Correct post-exercise unallocated collateral balances", async () => {
      const alphaUnallocatedCollateral =
        await this.CollateralManager.unallocatedCollateral(
          this.alice.address,
          this.Basis.address
        );

      const omegaUnallocatedCollateral =
        await this.CollateralManager.unallocatedCollateral(
          this.bob.address,
          this.Basis.address
        );
    });

    it("Emits 'Exercise' event with correct parameters", async () => {
      await expect(this.exerciseTransaction)
        .to.emit(this.TFM, "Exercise")
        .withArgs(this.strategyId);
    });

    it("Payout transferred between personal pools", async () => {
      const alicePersonalPoolAddress =
        await this.CollateralManager.personalPools(this.alice.address);
      const bobPersonalPoolAddress = await this.CollateralManager.personalPools(
        this.bob.address
      );

      await expect(this.exerciseTransaction).to.changeTokenBalances(
        this.Basis,
        [alicePersonalPoolAddress, bobPersonalPoolAddress],
        [EXERCISE_ONE.payout.mul(-1), EXERCISE_ONE.payout]
      );
    });

    // it("", async () => {});

    // Correct collateral manager state

    // tokens transferred - fees + personal pools
    // correct collateral state
  });
});
