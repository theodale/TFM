const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { freshDeployment } = require("../helpers/fixtures.js");
const { spearmint } = require("../helpers/actions/spearmint.js");
const { transfer } = require("../helpers/actions/transfer.js");
const {
  checkAllocations,
  checkReserves,
  checkWalletBalanceChanges,
} = require("../helpers/assertions.js");
const { STRATEGY, MINT, TRANSFER } = require("./PARAMETERS.js");

// TODO:
// - check omega transfer as successful call only does alpha transfer
// - cannot transfer a non-transferable strategy with a blank static party sig

describe("TRANSFER", () => {
  beforeEach(async () => {
    ({
      TFM: this.TFM,
      FundManager: this.FundManager,
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
      ({
        strategyId: this.strategyId,
        spearmintTransaction: this.spearmintTransaction,
      } = await spearmint(
        this.alice,
        this.bob,
        this.TFM,
        this.FundManager,
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

      this.transferTransaction = await transfer(
        this.TFM,
        this.FundManager,
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
      await checkAllocations(
        this.FundManager,
        this.strategyId,
        [this.alice, this.bob, this.carol],
        [
          {
            alphaBalance: 0,
            omegaBalance: 0,
          },
          {
            alphaBalance: 0,
            omegaBalance: MINT.omegaCollateralRequirement,
          },
          {
            alphaBalance: TRANSFER.recipientCollateralRequirement,
            omegaBalance: 0,
          },
        ]
      );
    });

    it("Premium exchanged between and fees taken from personal pools", async () => {
      await checkWalletBalanceChanges(
        this.FundManager,
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
      await checkReserves(
        this.FundManager,
        this.Basis,
        [this.alice, this.carol],
        [MINT.alphaCollateralRequirement, TRANSFER.premium]
      );
    });
  });
});
