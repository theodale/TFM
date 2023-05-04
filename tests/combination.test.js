const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { freshDeployment } = require("../helpers/fixtures.js");
const { spearmint } = require("../helpers/actions/spearmint.js");
const { combine } = require("../helpers/actions/combine.js");
const {
  checkAllocations,
  checkWalletBalanceChanges,
} = require("../helpers/assertions.js");
const { STRATEGY, MINT, COMBINATION } = require("./PARAMETERS.js");

describe("COMBINATION", () => {
  beforeEach(async () => {
    ({
      ActionLayer: this.ActionLayer,
      AssetLayer: this.AssetLayer,
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

      ({ strategyId: this.strategyTwoId } = await spearmint(
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

      this.combinationTransaction = await combine(
        this.ActionLayer,
        this.AssetLayer,
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

    it("Strategy one updated to combined state", async () => {
      const combinationStrategy = await this.ActionLayer.getStrategy(
        this.strategyOneId
      );

      expect(combinationStrategy.phase).to.deep.equal(
        COMBINATION.resultingPhase
      );
      expect(combinationStrategy.amplitude).to.equal(
        COMBINATION.resultingAmplitude
      );
    });

    it("Correct combined strategy collateral allocations post-combination", async () => {
      await checkAllocations(
        this.AssetLayer,
        this.strategyOneId,
        [this.alice, this.bob],
        [
          {
            alphaBalance: COMBINATION.resultingAlphaCollateralRequirement,
            omegaBalance: 0,
          },
          {
            alphaBalance: 0,
            omegaBalance: COMBINATION.resultingOmegaCollateralRequirement,
          },
        ]
      );
    });

    it("Correct reserve balances post-combination", async () => {});

    it("Fees sent from wallets to treasury", async () => {
      await checkWalletBalanceChanges(
        this.AssetLayer,
        this.Basis,
        [this.alice, this.bob],
        [
          COMBINATION.strategyOneAlphaFee.mul(-1),
          COMBINATION.strategyOneOmegaFee.mul(-1),
        ],
        this.combinationTransaction
      );

      await expect(this.combinationTransaction).to.changeTokenBalance(
        this.Basis,
        this.treasury.address,
        COMBINATION.strategyOneAlphaFee.add(COMBINATION.strategyOneAlphaFee)
      );
    });

    it("Strategy two deleted", async () => {
      const deletedStrategy = await this.ActionLayer.getStrategy(
        this.strategyTwoId
      );

      expect(deletedStrategy.phase).to.deep.equal([]);
      expect(deletedStrategy.amplitude).to.equal(0);
      expect(deletedStrategy.bra).to.equal(ethers.constants.AddressZero);
      expect(deletedStrategy.ket).to.equal(ethers.constants.AddressZero);
      expect(deletedStrategy.basis).to.equal(ethers.constants.AddressZero);
      expect(deletedStrategy.alpha).to.equal(ethers.constants.AddressZero);
      expect(deletedStrategy.omega).to.equal(ethers.constants.AddressZero);
    });

    it("Emits 'Combine' event with correct parameters", async () => {
      await expect(this.combinationTransaction)
        .to.emit(this.ActionLayer, "Combination")
        .withArgs(this.strategyOneId, this.strategyTwoId);
    });
  });
});

// TODO:
// - try both alignments
// - revert if shared between 3 parties
