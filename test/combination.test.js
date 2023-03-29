// const { expect } = require("chai");
// const { ethers } = require("hardhat");
// const { testDeployment } = require("../helpers/fixtures.js");
// const { mintAndDeposit } = require("../helpers/collateral-management.js");
// const { spearmint } = require("../helpers/actions.js");
// const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
// const { SPEARMINT_TEST_PARAMETERS_1 } = require("./test-parameters.js");

// describe("COMBINATION", () => {
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
//   });

//   it("Combine", async () => {
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
//   });
// });
