const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { freshDeployment } = require("../helpers/fixtures.js");
const { spearmint } = require("../helpers/actions/spearmint.js");
const { novate } = require("../helpers/actions/novate.js");
const {
  checkAllocations,
  checkWalletBalanceChanges,
} = require("../helpers/assertions.js");
const { STRATEGY, MINT, NOVATION } = require("./PARAMETERS.js");

describe("NOVATION", () => {
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
      carol: this.carol,
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
        this.bob,
        this.carol,
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

      this.novationTransaction = await novate(
        this.ActionLayer,
        this.AssetLayer,
        this.Basis,
        this.strategyOneId,
        this.strategyTwoId,
        this.bob,
        this.alice,
        this.bob,
        this.oracle,
        NOVATION.strategyOneResultingAlphaCollateralRequirement,
        NOVATION.strategyOneResultingOmegaCollateralRequirement,
        NOVATION.strategyTwoResultingAlphaCollateralRequirement,
        NOVATION.strategyTwoResultingOmegaCollateralRequirement,
        NOVATION.strategyOneResultingAmplitude,
        NOVATION.strategyTwoResultingAmplitude,
        NOVATION.fee
      );
    });

    it("Strategy one updated to combined state", async () => {
      // const combinationStrategy = await this.ActionLayer.getStrategy(
      //   this.strategyOneId
      // );
      // expect(combinationStrategy.phase).to.deep.equal(
      //   COMBINATION.resultingPhase
      // );
      // expect(combinationStrategy.amplitude).to.equal(
      //   COMBINATION.resultingAmplitude
      // );
    });

    it("Correct combined strategy collateral allocations post-combination", async () => {
      // await checkAllocations(
      //   this.AssetLayer,
      //   this.strategyOneId,
      //   [this.alice, this.bob],
      //   [
      //     {
      //       alphaBalance: COMBINATION.resultingAlphaCollateralRequirement,
      //       omegaBalance: 0,
      //     },
      //     {
      //       alphaBalance: 0,
      //       omegaBalance: COMBINATION.resultingOmegaCollateralRequirement,
      //     },
      //   ]
      // );
    });

    it("Correct reserve balances post-combination", async () => {});

    it("Fees sent from wallets to treasury", async () => {
      // await checkWalletBalanceChanges(
      //   this.AssetLayer,
      //   this.Basis,
      //   [this.alice, this.bob],
      //   [
      //     COMBINATION.strategyOneAlphaFee.mul(-1),
      //     COMBINATION.strategyOneOmegaFee.mul(-1),
      //   ],
      //   this.combinationTransaction
      // );
      // await expect(this.combinationTransaction).to.changeTokenBalance(
      //   this.Basis,
      //   this.treasury.address,
      //   COMBINATION.strategyOneAlphaFee.add(COMBINATION.strategyOneAlphaFee)
      // );
    });

    // it("Emits 'Combine' event with correct parameters", async () => {
    //   await expect(this.combinationTransaction)
    //     .to.emit(this.ActionLayer, "Combination")
    //     .withArgs(this.strategyOneId, this.strategyTwoId);
    // });
  });
});
