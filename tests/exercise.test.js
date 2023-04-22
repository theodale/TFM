// const { expect } = require("chai");
// const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

// const { freshDeployment } = require("../helpers/fixtures.js");
// const { spearmint } = require("../helpers/actions/spearmint.js");
// const { exercise } = require("../helpers/actions/exercise.js");
// const {
//   checkUnallocatedCollateralBalances,
//   checkPoolBalanceChanges,
// } = require("../helpers/assertions.js");
// const { STRATEGY, SPEARMINT, EXERCISE } = require("./test-parameters.js");

// describe("EXERCISE", () => {
//   beforeEach(async () => {
//     ({
//       TFM: this.TFM,
//       CollateralManager: this.CollateralManager,
//       BRA: this.BRA,
//       KET: this.KET,
//       Basis: this.Basis,
//       Utils: this.Utils,
//       oracle: this.oracle,
//       owner: this.owner,
//       alice: this.alice,
//       bob: this.bob,
//     } = await loadFixture(freshDeployment));
//   });

//   describe("Successful Call", () => {
//     beforeEach(async () => {
//       ({
//         strategyId: this.strategyId,
//         spearmintTransaction: this.spearmintTransaction,
//       } = await spearmint(
//         this.alice,
//         this.bob,
//         this.TFM,
//         this.CollateralManager,
//         this.oracle,
//         this.BRA,
//         this.KET,
//         this.Basis,
//         SPEARMINT.premium,
//         STRATEGY.transferable,
//         STRATEGY.expiry,
//         STRATEGY.amplitude,
//         STRATEGY.phase,
//         SPEARMINT.alphaCollateralRequirement,
//         SPEARMINT.omegaCollateralRequirement,
//         SPEARMINT.alphaFee,
//         SPEARMINT.omegaFee
//       ));

//       this.exerciseTransaction = await exercise(
//         this.TFM,
//         this.strategyId,
//         this.oracle,
//         EXERCISE.payout
//       );
//     });

//     it("Exercised strategy deleted", async () => {
//       const strategy = await this.TFM.getStrategy(this.strategyId);

//       expect(strategy.expiry).to.equal(0);
//       expect(strategy.amplitude).to.equal(0);
//       expect(strategy.transferable).to.equal(false);
//       expect(strategy.alpha).to.equal(ethers.constants.AddressZero);
//       expect(strategy.omega).to.equal(ethers.constants.AddressZero);
//       expect(strategy.bra).to.equal(ethers.constants.AddressZero);
//       expect(strategy.ket).to.equal(ethers.constants.AddressZero);
//       expect(strategy.basis).to.equal(ethers.constants.AddressZero);
//       expect(strategy.phase).to.deep.equal([]);
//     });

//     it("Correct post-exercise unallocated collateral balances", async () => {
//       await checkUnallocatedCollateralBalances(
//         this.CollateralManager,
//         this.Basis,
//         [this.alice, this.bob],
//         [
//           SPEARMINT.alphaCollateralRequirement.sub(EXERCISE.payout),
//           SPEARMINT.omegaCollateralRequirement.add(EXERCISE.payout),
//         ]
//       );
//     });

//     it("Emits 'Exercise' event with correct parameters", async () => {
//       await expect(this.exerciseTransaction)
//         .to.emit(this.TFM, "Exercise")
//         .withArgs(this.strategyId);
//     });

//     it("Payout transferred between personal pools", async () => {
//       await checkPoolBalanceChanges(
//         this.CollateralManager,
//         this.Basis,
//         [this.alice, this.bob],
//         [EXERCISE.payout.mul(-1), EXERCISE.payout],
//         this.exerciseTransaction
//       );
//     });
//   });
// });
