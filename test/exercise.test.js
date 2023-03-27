// const { expect } = require("chai");
// const { ethers } = require("hardhat");
// const { testDeployment } = require("../helpers/fixtures.js");
// const { mintAndDeposit } = require("../helpers/collateral-management.js");
// const { spearmint } = require("../helpers/actions.js");
// const { generateExerciseTerms } = require("../helpers/terms.js");
// const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

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
//     } = await loadFixture(testDeployment));

//     // Give unallocated collateral in this.basis to alice and bob
//     await mintAndDeposit(
//       this.CollateralManager,
//       this.Basis,
//       this.alice,
//       this.alphaDeposit
//     );
//     await mintAndDeposit(
//       this.CollateralManager,
//       this.Basis,
//       this.bob,
//       this.omegaDeposit
//     );

//     this.strategyId = await spearmint(
//       this.alice,
//       this.bob,
//       this.premium,
//       this.transferable,
//       this.TFM,
//       this.owner,
//       this.expiry,
//       this.BRA,
//       this.KET,
//       this.Basis,
//       this.amplitude,
//       this.phase,
//       this.alphaCollateralRequirement,
//       this.omegaCollateralRequirement,
//       this.alphaFee,
//       this.omegaFee
//     );
//   });

//   it("exercise", async () => {
//     const { exerciseTerms, oracleSignature } = await generateExerciseTerms(
//       this.TFM,
//       this.owner,
//       this.payout,
//       this.alphaFee,
//       this.omegaFee,
//       this.expiry,
//       this.BRA,
//       this.KET,
//       this.Basis,
//       this.amplitude,
//       this.phase
//     );

//     const exerciseParameters = {
//       oracleSignature: oracleSignature,
//       strategyId: this.strategyId,
//     };

//     await this.TFM.exercise(exerciseTerms, exerciseParameters);
//   });
// });
