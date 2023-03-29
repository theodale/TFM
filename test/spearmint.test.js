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

  // TODO:
  // - Insufficient collateral for all requirements, fees, preimium
  // - Incorrect signatures terms + approvals
  // - oracle nonce incorrect -> check this in another folder - check this method reverts
  // - mint nonce incorrect - increments mint nonce

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

    it("Newly minted strategy has correct state", async () => {
      const strategy = await this.TFM.getStrategy(this.strategyId);

      expect(strategy.alpha).to.equal(this.alice.address);
      expect(strategy.omega).to.equal(this.bob.address);
      expect(strategy.transferable).to.equal(STRATEGY_ONE.transferable);
      expect(strategy.expiry).to.equal(STRATEGY_ONE.expiry);
      expect(strategy.amplitude).to.equal(STRATEGY_ONE.amplitude);
      expect(strategy.bra).to.equal(this.BRA.address);
      expect(strategy.ket).to.equal(this.KET.address);
      expect(strategy.basis).to.equal(this.Basis.address);
      expect(strategy.phase).to.deep.equal(STRATEGY_ONE.phase);
      expect(strategy.actionNonce).to.equal(0);
    });

    it("Correct resulting collateral state (allocated/unallocated)", async () => {
      const alphaAllocatedCollateral =
        await this.CollateralManager.allocatedCollateral(
          this.alice.address,
          this.strategyId
        );
      const omegaAllocatedCollateral =
        await this.CollateralManager.allocatedCollateral(
          this.bob.address,
          this.strategyId
        );

      // Check collateral alloacted to newly minted strategy
      expect(alphaAllocatedCollateral).to.equal(
        SPEARMINT_ONE.alphaCollateralRequirement
      );
      expect(omegaAllocatedCollateral).to.equal(
        SPEARMINT_ONE.omegaCollateralRequirement
      );

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

      // Check resulting unallocated collateral
      if (SPEARMINT_ONE.premium > 0) {
        expect(omegaUnallocatedCollateral).to.equal(SPEARMINT_ONE.premium);
        expect(alphaUnallocatedCollateral).to.equal(0);
      } else {
        expect(alphaUnallocatedCollateral).to.equal(SPEARMINT_ONE.premium);
        expect(omegaUnallocatedCollateral).to.equal(0);
      }
    });

    it("Tokens used for fee/premium taken from minter's personal pools", async () => {
      const alicePersonalPoolAddress =
        await this.CollateralManager.personalPools(this.alice.address);
      const bobPersonalPoolAddress = await this.CollateralManager.personalPools(
        this.bob.address
      );

      // Check tokens leave pools
      await expect(this.spearmintTransaction).to.changeTokenBalance(
        this.Basis,
        alicePersonalPoolAddress,
        SPEARMINT_ONE.alphaFee.add(SPEARMINT_ONE.premium).mul(-1)
      );
      await expect(this.spearmintTransaction).to.changeTokenBalance(
        this.Basis,
        bobPersonalPoolAddress,
        SPEARMINT_ONE.omegaFee.sub(SPEARMINT_ONE.premium).mul(-1)
      );
    });

    it("Fees transferred to treasury", async () => {
      await expect(this.spearmintTransaction).to.changeTokenBalance(
        this.Basis,
        this.owner,
        SPEARMINT_ONE.alphaFee.add(SPEARMINT_ONE.omegaFee)
      );
    });

    it("Emits 'Spearmint' event with correct parameters", async () => {
      await expect(this.spearmintTransaction)
        .to.emit(this.TFM, "Spearmint")
        .withArgs(this.strategyId);
    });
  });
});
