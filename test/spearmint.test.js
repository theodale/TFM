const { expect } = require("chai");
const { ethers } = require("hardhat");
const { deploy } = require("../helpers/deploy.js");
const { generateSpearmintTerms } = require("../helpers/terms.js");
const { signSpearmintParameters } = require("../helpers/meta-transactions.js");
const { mintAndDeposit } = require("../helpers/collateral-management.js");
const { spearmint } = require("../helpers/actions.js");

describe("Spearmint", () => {
  let res;
  before(async () => {
    [this.owner, this.alice, this.bob] = await ethers.getSigners();
    this.eth = "0x59C877ece1121061773DD1551649028C6FC1423E";
  });

  beforeEach(async () => {
    ({
      TFM: this.TFM,
      CollateralManager: this.collateralManager,
      MockERC20: this.basis,
      Utils: this.utils,
    } = await deploy(this.owner));
    res = await generateSpearmintTerms(this.owner,16273919,1000,2000,100,100,1,this.eth,this.basis.address,this.basis.address,2000000,[[2000000,14000000]])

  });

  describe("Oracle Signature Verification", () => {
    it("should validate correct Oracle signature", async () => {
        await this.utils.validateSpearmintTerms(this.res.spearmintTerms,this.res.trufinOracleSignature,this.owner.address)
    });
    
    it("should revert with wrong signer", async () => {
      await expect(
        this.utils.validateSpearmintTerms(res.spearmintTerms,res.trufinOracleSignature,this.alice.address)
      ).to.be.revertedWith("TFM: Invalid Trufin oracle signature");    
  });

    it("should revert with wrong terms", async () => {
      res.spearmintTerms.expiry = 16270000
      await expect(
        this.utils.validateSpearmintTerms(res.spearmintTerms,res.trufinOracleSignature,this.alice.address)
      ).to.be.revertedWith("TFM: Invalid Trufin oracle signature");    
    })
})

}
  //
  // it("Sencond spearmint test", async () => {});
);
