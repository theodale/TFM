const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

const { freshDeployment } = require("../helpers/fixtures.js");
const { spearmint } = require("../helpers/actions/spearmint.js");
const {
  checkAllocations,
  checkReserves,
  checkWalletBalanceChanges,
} = require("../helpers/assertions.js");
const { STRATEGY, MINT } = require("./PARAMETERS.js");

describe("SPEARMINT", () => {
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
    });

    it("Newly minted strategy has correct state", async () => {
      const strategy = await this.ActionLayer.getStrategy(this.strategyId);

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
        this.AssetLayer,
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

    it("Correct reserve balances post-mint", async () => {
      await checkReserves(
        this.AssetLayer,
        this.Basis,
        [this.alice, this.bob],
        [0, 0]
      );
    });

    it("Premium exchanged between and fees taken from wallets", async () => {
      await checkWalletBalanceChanges(
        this.AssetLayer,
        this.Basis,
        [this.alice, this.bob],
        [
          MINT.alphaFee.add(MINT.premium).mul(-1),
          MINT.omegaFee.sub(MINT.premium).mul(-1),
        ],
        this.spearmintTransaction
      );
    });

    it("Fees sent to treasury", async () => {
      await expect(this.spearmintTransaction).to.changeTokenBalance(
        this.Basis,
        this.treasury,
        MINT.alphaFee.add(MINT.omegaFee)
      );
    });

    it("Emits 'Spearmint' event with correct parameters", async () => {
      await expect(this.spearmintTransaction)
        .to.emit(this.ActionLayer, "Spearmint")
        .withArgs(this.strategyId);
    });
  });

  // describe("Reversions", () => {
  //   beforeEach(async () => {
  //     ({ mintTerms: this.mintTerms, oracleSignature } = await getMintTerms(
  //       this.ActionLayer,
  //       this.oracle,
  //       STRATEGY.expiry,
  //       MINT.alphaCollateralRequirement,
  //       MINT.omegaCollateralRequirement,
  //       MINT.alphaFee,
  //       MINT.omegaFee,
  //       this.BRA,
  //       this.KET,
  //       this.Basis,
  //       STRATEGY.amplitude,
  //       STRATEGY.phase
  //     ));

  //     // this.mintParameters = await signmint(
  //     //   this.alice,
  //     //   this.bob,
  //     //   oracleSignature,
  //     //   MINT.premium,
  //     //   STRATEGY.transferable,
  //     //   this.ActionLayer
  //     // );
  //   });

  //   // TODO:
  //   // - Insufficient collateral for all requirements, fees, preimium
  //   // - Incorrect signatures terms + approvals
  //   // - oracle nonce incorrect -> check this in another folder - check this method reverts
  //   // - mint nonce incorrect - increments mint nonce

  //   // it("Reverts if alpha has insufficient unallocated collateral to pay fee", async () => {
  //   //   // this.ActionLayer.withdraw();
  //   // });

  //   // it("Reverts if omega has insufficient unallocated collateral to pay fee", async () => {
  //   //   // asd
  //   // });
  // });
});
