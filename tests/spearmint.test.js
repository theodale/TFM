const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { freshDeployment } = require("../helpers/fixtures.js");
const { getMintTerms } = require("../helpers/terms/mint.js");
const { signSpearmint } = require("../helpers/signing/spearmint.js");
const { spearmint } = require("../helpers/actions/spearmint.js");
const {
  checkCollateralAllocations,
  checkUnallocatedCollateralBalances,
  checkPoolBalanceChanges,
} = require("../helpers/assertions.js");
const { STRATEGY, SPEARMINT } = require("./test-parameters.js");

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
      treasury: this.treasury,
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
    });

    it("Newly minted strategy has correct state", async () => {
      const strategy = await this.TFM.getStrategy(this.strategyId);

      expect(strategy.alpha).to.equal(this.alice.address);
      expect(strategy.omega).to.equal(this.bob.address);
      expect(strategy.transferable).to.equal(STRATEGY.transferable);
      expect(strategy.expiry).to.equal(STRATEGY.expiry);
      expect(strategy.amplitude).to.equal(STRATEGY.amplitude);
      expect(strategy.bra).to.equal(this.BRA.address);
      expect(strategy.ket).to.equal(this.KET.address);
      expect(strategy.basis).to.equal(this.Basis.address);
      expect(strategy.phase).to.deep.equal(STRATEGY.phase);
      expect(strategy.actionNonce).to.equal(0);
    });

    it("Correct strategy collateral allocations", async () => {
      await checkCollateralAllocations(
        this.CollateralManager,
        this.strategyId,
        [this.alice, this.bob],
        [
          SPEARMINT.alphaCollateralRequirement,
          SPEARMINT.omegaCollateralRequirement,
        ]
      );
    });

    it("Correct unallocated collateral balances post-spearmint", async () => {
      await checkUnallocatedCollateralBalances(
        this.CollateralManager,
        this.Basis,
        [this.alice, this.bob],
        [0, 0]
      );
    });

    it("Premium exchanged between and fees taken from personal pools", async () => {
      await checkPoolBalanceChanges(
        this.CollateralManager,
        this.Basis,
        [this.alice, this.bob],
        [
          SPEARMINT.alphaFee.add(SPEARMINT.premium).mul(-1),
          SPEARMINT.omegaFee.sub(SPEARMINT.premium).mul(-1),
        ],
        this.spearmintTransaction
      );
    });

    it("Fees sent to treasury", async () => {
      await expect(this.spearmintTransaction).to.changeTokenBalance(
        this.Basis,
        this.treasury,
        SPEARMINT.alphaFee.add(SPEARMINT.omegaFee)
      );
    });

    it("Emits 'Spearmint' event with correct parameters", async () => {
      await expect(this.spearmintTransaction)
        .to.emit(this.TFM, "Spearmint")
        .withArgs(this.strategyId);
    });
  });

  describe("Reversions", () => {
    beforeEach(async () => {
      ({ mintTerms: this.mintTerms, oracleSignature } = await getMintTerms(
        this.TFM,
        this.oracle,
        STRATEGY.expiry,
        SPEARMINT.alphaCollateralRequirement,
        SPEARMINT.omegaCollateralRequirement,
        SPEARMINT.alphaFee,
        SPEARMINT.omegaFee,
        this.BRA,
        this.KET,
        this.Basis,
        STRATEGY.amplitude,
        STRATEGY.phase
      ));

      // this.spearmintParameters = await signSpearmint(
      //   this.alice,
      //   this.bob,
      //   oracleSignature,
      //   SPEARMINT.premium,
      //   STRATEGY.transferable,
      //   this.TFM
      // );
    });

    // TODO:
    // - Insufficient collateral for all requirements, fees, preimium
    // - Incorrect signatures terms + approvals
    // - oracle nonce incorrect -> check this in another folder - check this method reverts
    // - mint nonce incorrect - increments mint nonce

    // it("Reverts if alpha has insufficient unallocated collateral to pay fee", async () => {
    //   // this.CollateralManager.withdraw();
    // });

    // it("Reverts if omega has insufficient unallocated collateral to pay fee", async () => {
    //   // asd
    // });
  });
});
