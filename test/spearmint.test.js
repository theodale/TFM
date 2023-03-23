const { expect } = require("chai");
const { ethers,BigNumber } = require("hardhat");
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
    await mintAndDeposit(this.collateralManager,this.basis,this.alice,1000000000)
    await mintAndDeposit(this.collateralManager,this.basis,this.bob,1000000000)  
    res = await generateSpearmintTerms(this.owner,16273919,1000,2000,100,100,1,this.eth,this.basis.address,this.basis.address,2000000,[[2000000,14000000]])

  });

  describe("Oracle Signature Verification", () => {
    it("should mint with correct values", async () => {
        await spearmint(this.alice,this.bob,100,true,this.TFM,this.owner,1234,this.eth,this.basis.address,this.basis.address,1,[[1,10]],100,0,10,10)
        //await expect(this.utils.validateSpearmintTerms(res.spearmintTerms,res.trufinOracleSignature,this.owner.address)).to.be.revertedWith("TFM: Invalid Trufin oracle signature");   
    });
    
  //   it("should revert with wrong oracle", async () => {
  //     await expect(
  //        this.utils.validateSpearmintTerms(res.spearmintTerms,res.trufinOracleSignature,this.alice.address)
  //     ).to.be.revertedWith("");    
  // });

  //   it("should revert with wrong terms", async () => {
  //     res.spearmintTerms.expiry = 16270000
  //     await expect(
  //        this.utils.validateSpearmintTerms(res.spearmintTerms,res.trufinOracleSignature,this.owner.address)
  //     ).to.be.revertedWith("TFM: Invalid Trufin oracle signature");    
  //   })
})
// describe("Alpha/Omega Signature Verification", () => {
//   it("should validate correct Alpha/Omega signature", async () => {
//       const sign = await signSpearmintParameters(this.alice,this.bob,res.trufinOracleSignature,this.alice.address,this.bob.address,1000,true,1)
//       expect(await this.utils.ensureSpearmintApprovals(sign.spearmintParameters,1)).to.be.revertedWith("Alpha signature invalid")
//       //await this.utils.ensureSpearmintApprovals(sign.spearmintParameters,1)
//   });

//   it("should revert with wrong alpha", async () => {
//     const sign = await signSpearmintParameters(this.alice,this.bob,res.trufinOracleSignature,this.alice.address,this.bob.address,1000,true,1)
//     sign.spearmintParameters.alpha = this.owner.address 
//     expect(await this.utils.ensureSpearmintApprovals(sign.spearmintParameters,1)).to.be.revertedWith("Omega signature invalid")
// });
  
// //   it("should revert with wrong signer", async () => {
// //     await expect(
// //       this.utils.validateSpearmintTerms(res.spearmintTerms,res.trufinOracleSignature,this.alice.address)
// //     ).to.be.revertedWith("TFM: Invalid Trufin oracle signature");    
// // });

// //   it("should revert with wrong terms", async () => {
// //     res.spearmintTerms.expiry = 16270000
// //     await expect(
// //       this.utils.validateSpearmintTerms(res.spearmintTerms,res.trufinOracleSignature,this.alice.address)
// //     ).to.be.revertedWith("TFM: Invalid Trufin oracle signature");    
// //   })
// })

}
  //
  // it("Sencond spearmint test", async () => {});
);
