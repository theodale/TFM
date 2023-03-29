// const { expect } = require("chai");
// const { ethers } = require("hardhat");
// const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

// const { testDeployment } = require("../helpers/fixtures.js");
// const { getTransferTerms } = require("../helpers/terms.js");
// const { spearmint } = require("../helpers/actions.js");
// const { signTransferParameters } = require("../helpers/sign.js");
// const { mintAndDeposit } = require("../helpers/collateral-management.js");

// const { SPEARMINT_TEST_PARAMETERS_1 } = require("./test-parameters.js");

// describe("TRANSFER", () => {
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
//       carol: this.carol,
//     } = await loadFixture(testDeployment));
//   });

//   it("Transfer transferable strategy", async () => {
//     this.strategyId = await spearmint(
//       this.alice,
//       this.bob,
//       this.TFM,
//       this.CollateralManager,
//       this.oracle,
//       this.BRA,
//       this.KET,
//       this.Basis,
//       SPEARMINT_TEST_PARAMETERS_1
//     );

//     let recipientCollateralRequirement = 100;
//     let senderFee = 200;
//     let recipientFee = 300;

//     const { oracleSignature, transferTerms } = await getTransferTerms(
//       this.TFM,
//       this.strategyId,
//       this.oracle,
//       recipientCollateralRequirement,
//       senderFee,
//       recipientFee,
//       true
//     );

//     let premium = 400;

//     const transferParameters = await signTransferParameters(
//       this.alice,
//       this.carol,
//       this.bob,
//       oracleSignature,
//       this.strategyId,
//       premium
//     );

//     await mintAndDeposit(
//       this.CollateralManager,
//       this.Basis,
//       this.alice,
//       premium
//     );

//     await mintAndDeposit(
//       this.CollateralManager,
//       this.Basis,
//       this.carol,
//       recipientCollateralRequirement
//     );

//     await this.TFM.transfer(transferTerms, transferParameters);
//   });
// });

// // Sender sig invalid
