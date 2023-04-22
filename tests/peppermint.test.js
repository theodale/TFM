const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { freshDeployment } = require("../helpers/fixtures.js");
const { peppermint } = require("../helpers/actions/peppermint.js");
const {
  checkAllocations,
  checkReserves,
  checkWalletBalanceChanges,
} = require("../helpers/assertions.js");
const { STRATEGY, MINT } = require("./PARAMETERS.js");

describe("PEPPERMINT", () => {
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
      carol: this.pepperminter,
    } = await loadFixture(freshDeployment));
  });

  describe("Successful Call", () => {
    beforeEach(async () => {
      ({
        strategyId: this.strategyId,
        peppermintTransaction: this.peppermintTransaction,
      } = await peppermint(
        this.alice,
        this.bob,
        this.pepperminter,
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
      await checkAllocations(
        this.FundManager,
        this.strategyId,
        [this.alice, this.bob],
        [
          {
            alphaBalance: MINT.alphaCollateralRequirement,
            omegaBalance: 0,
          },
          {
            alphaBalance: 0,
            omegaBalance: MINT.omegaCollateralRequirement,
          },
        ]
      );
    });

    it("Correct unallocated collateral balances post-peppermint", async () => {
      await checkReserves(
        this.FundManager,
        this.Basis,
        [this.alice, this.bob],
        [0, 0]
      );
    });

    it("Premium exchanged between and fees taken from personal pools", async () => {
      await checkWalletBalanceChanges(
        this.FundManager,
        this.Basis,
        [this.alice, this.bob],
        [
          MINT.alphaFee.add(MINT.premium).mul(-1),
          MINT.omegaFee.sub(MINT.premium).mul(-1),
        ],
        this.peppermintTransaction
      );
    });

    it("Fees sent to treasury", async () => {
      await expect(this.peppermintTransaction).to.changeTokenBalance(
        this.Basis,
        this.treasury,
        MINT.alphaFee.add(MINT.omegaFee)
      );
    });

    it("Emits 'Peppermint' event with correct parameters", async () => {
      await expect(this.peppermintTransaction)
        .to.emit(this.TFM, "Peppermint")
        .withArgs(this.strategyId);
    });
  });
});
