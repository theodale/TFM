const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { freshDeployment } = require("../helpers/fixtures.js");
const { spearmint } = require("../helpers/actions/spearmint.js");
const { transfer } = require("../helpers/actions/transfer.js");
const {
  checkCollateralAllocations,
  checkUnallocatedCollateralBalances,
  checkPoolBalanceChanges,
} = require("../helpers/assertions.js");
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

    it("Emits 'Transfer' event with correct parameters", async () => {
      await expect(this.transferTransaction)
        .to.emit(this.TFM, "Transfer")
        .withArgs(this.strategyId);
    });

    it("Correct strategy collateral allocations post-transfer", async () => {
      await checkCollateralAllocations(
        this.CollateralManager,
        this.strategyId,
        [this.alice, this.bob, this.carol],
        [
          0,
          TRANSFER.recipientCollateralRequirement,
          SPEARMINT.omegaCollateralRequirement,
        ]
      );
    });

    it("Premium exchanged between and fees taken from personal pools", async () => {
      await checkPoolBalanceChanges(
        this.CollateralManager,
        this.Basis,
        [this.alice, this.carol],
        [
          TRANSFER.premium.mul(-1).sub(TRANSFER.senderFee),
          TRANSFER.premium.sub(TRANSFER.recipientFee),
        ],
        this.transferTransaction
      );
    });

    it("Correct unallocated collateral balances post-transfer", async () => {
      await checkUnallocatedCollateralBalances(
        this.CollateralManager,
        this.Basis,
        [this.alice, this.bob, this.carol],
        [SPEARMINT.alphaCollateralRequirement, 0, TRANSFER.premium]
      );
    });

    // TODO:
    // - check omega transfer
    // - cannot transfer a non-transferable strategy with a blank static party sig
  });
});
