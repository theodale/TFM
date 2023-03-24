const { expect } = require("chai");
const { ethers, BigNumber } = require("hardhat");
const { deploy } = require("../helpers/deploy.js");
const { generateSpearmintTerms } = require("../helpers/terms.js");
const { signSpearmintParameters } = require("../helpers/meta-transactions.js");
const { mintAndDeposit } = require("../helpers/collateral-management.js");
const { spearmint } = require("../helpers/actions.js");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { zeroState, depositState } = require("../helpers/utils.js");
const { PANIC_CODES } = require("@nomicfoundation/hardhat-chai-matchers/panic");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("Spearmint", () => {
  let res;
  let sp;
  let premium = -1000;
  let alphaCollateralRequirement = 0;
  let omegaCollateralRequirement = 2000;
  let alphaFee = 10;
  let omegaFee = 10;
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
    const oracleNonce = await this.TFM.oracleNonce();
    await mintAndDeposit(
      this.collateralManager,
      this.basis,
      this.alice,
      1000000000
    );
    await mintAndDeposit(
      this.collateralManager,
      this.basis,
      this.bob,
      1000000000
    );
    res = await generateSpearmintTerms(
      this.owner,
      16273919,
      alphaCollateralRequirement,
      omegaCollateralRequirement,
      alphaFee,
      omegaFee,
      oracleNonce,
      this.eth,
      this.basis.address,
      this.basis.address,
      2000000,
      [[2000000, 14000000]]
    );
    const mintNonce = await this.TFM.getMintNonce(
      this.alice.address,
      this.bob.address
    );
    sp = await signSpearmintParameters(
      this.alice,
      this.bob,
      res.trufinOracleSignature,
      this.alice.address,
      this.bob.address,
      premium,
      true,
      mintNonce
    );
  });

  it("should mint with correct values", async () => {
    spearmint(
      this.alice,
      this.bob,
      premium,
      true,
      this.TFM,
      this.owner,
      1234,
      this.eth,
      this.basis.address,
      this.basis.address,
      1,
      [[1, 10]],
      alphaCollateralRequirement,
      omegaCollateralRequirement,
      alphaFee,
      omegaFee
    );
  });

  it("should revert with wrong oracle signature", async () => {
    await expect(
      spearmint(
        this.alice,
        this.bob,
        premium,
        true,
        this.TFM,
        this.alice,
        1234,
        this.eth,
        this.basis.address,
        this.basis.address,
        1,
        [[1, 10]],
        alphaCollateralRequirement,
        omegaCollateralRequirement,
        alphaFee,
        omegaFee
      )
    ).to.be.revertedWith("TFM: Invalid Trufin oracle signature");
  });

  it("should revert with wrong signature parameters", async () => {
    res.spearMintTerms.alphaCollateralRequirement = 10;
    await expect(
      this.TFM.spearmint(res.spearMintTerms, sp.spearmintParameters)
    ).to.be.revertedWith("TFM: Invalid Trufin oracle signature");
  });

  it("should revert with too little posted collateral", async () => {
    await expect(
      spearmint(
        this.alice,
        this.bob,
        1000000000,
        true,
        this.TFM,
        this.owner,
        1234,
        this.eth,
        this.basis.address,
        this.basis.address,
        1,
        [[1, 10]],
        alphaCollateralRequirement,
        omegaCollateralRequirement,
        alphaFee,
        omegaFee
      )
    ).to.be.revertedWithPanic(0x11);
  });

  it("should emit an event when a strategy is minted", async () => {
    await expect(this.TFM.spearmint(res.spearMintTerms, sp.spearmintParameters))
      .to.emit(this.TFM, "Spearmint")
      .withArgs(0);
  });

  it("should correctly increase strategy and mintNonce counters", async () => {
    await this.TFM.spearmint(res.spearMintTerms, sp.spearmintParameters);

    const strategyId = await this.TFM.strategyCounter();
    expect(strategyId).to.equal(1);
    await spearmint(
      this.alice,
      this.bob,
      premium,
      false,
      this.TFM,
      this.owner,
      1234,
      this.eth,
      this.basis.address,
      this.basis.address,
      1,
      [[1, 10]],
      alphaCollateralRequirement,
      omegaCollateralRequirement,
      alphaFee,
      omegaFee
    );
    const strategyId2 = await this.TFM.strategyCounter();
    expect(strategyId2).to.equal(2);
    let mintNonce = await this.TFM.getMintNonce(
      this.alice.address,
      this.bob.address
    );
    expect(mintNonce).to.equal(2);
    const oracleNonce = await this.TFM.oracleNonce();
    const res1 = await generateSpearmintTerms(
      this.owner,
      16273919,
      200,
      90,
      1,
      4,
      oracleNonce,
      this.eth,
      this.basis.address,
      this.basis.address,
      2000000,
      [[2000000, 14000000]]
    );

    const sp1 = await signSpearmintParameters(
      this.alice,
      this.bob,
      res1.trufinOracleSignature,
      this.alice.address,
      this.bob.address,
      100,
      true,
      mintNonce
    );

    await expect(
      this.TFM.spearmint(res1.spearMintTerms, sp1.spearmintParameters)
    )
      .to.emit(this.TFM, "Spearmint")
      .withArgs(2);
  });

  it("should map correct strategy to id", async () => {
    await spearmint(
      this.alice,
      this.bob,
      premium,
      true,
      this.TFM,
      this.owner,
      1234,
      this.eth,
      this.basis.address,
      this.basis.address,
      1,
      [[1, 10]],
      alphaCollateralRequirement,
      omegaCollateralRequirement,
      alphaFee,
      omegaFee
    );
    await spearmint(
      this.alice,
      this.bob,
      200,
      false,
      this.TFM,
      this.owner,
      1234,
      this.eth,
      this.basis.address,
      this.basis.address,
      1,
      [[1, 10]],
      100,
      0,
      10,
      10
    );
    s = await this.TFM.getStrategy(0);
    expect(s.transferable).to.equal(true);
    s1 = await this.TFM.getStrategy(1);
    expect(s1.transferable).to.equal(false);
  });

  it("should revert if nonce hasn't been updated in a while", async () => {
    await time.increase(7200);
    await expect(
      this.TFM.spearmint(res.spearMintTerms, sp.spearmintParameters)
    ).to.be.revertedWith(
      "TFM: Contract locked due as oracle nonce has not been updated"
    );
  });

  it("should revert if nonce is outdated", async () => {
    let mintNonce = await this.TFM.getMintNonce(
      this.alice.address,
      this.bob.address
    );
    const res2 = await generateSpearmintTerms(
      this.owner,
      16273919,
      1000,
      2000,
      100,
      100,
      3,
      this.eth,
      this.basis.address,
      this.basis.address,
      2000000,
      [[2000000, 14000000]]
    );
    const { alphaSignature, omegaSignature, spearmintParameters } =
      await signSpearmintParameters(
        this.alice,
        this.bob,
        res2.trufinOracleSignature,
        this.alice.address,
        this.bob.address,
        1000,
        true,
        mintNonce
      );
    await expect(
      this.TFM.spearmint(res2.spearMintTerms, spearmintParameters)
    ).to.be.revertedWith("TFM: Oracle nonce has expired");

    await expect(
      this.TFM.spearmint(res2.spearMintTerms, spearmintParameters)
    ).to.be.revertedWith("TFM: Oracle nonce has expired");
  });

  it("should revert if alpha/omega signature is wrong", async () => {
    sp.spearmintParameters.transferable = false;
    await expect(
      this.TFM.spearmint(res.spearMintTerms, sp.spearmintParameters)
    ).to.be.revertedWith("Alpha signature invalid");
  });
  it("should revert if same mintNonce is used", async () => {
    await this.TFM.spearmint(res.spearMintTerms, sp.spearmintParameters);
    await expect(
      this.TFM.spearmint(res.spearMintTerms, sp.spearmintParameters)
    ).to.be.revertedWith("Alpha signature invalid");
    const mn = await this.TFM.getMintNonce(
      this.alice.address,
      this.bob.address
    );
    expect(mn).to.equal(1);
    console.log("hi");
    sp1 = await signSpearmintParameters(
      this.alice,
      this.bob,
      res.trufinOracleSignature,
      this.alice.address,
      this.bob.address,
      premium,
      true,
      mn
    );
    await this.TFM.spearmint(res.spearMintTerms, sp1.spearmintParameters);
  });
  it("should take premium from the correct person and allocate fees to treasury", async () => {
    const prea = await this.collateralManager.unallocatedCollateral(
      this.alice.address,
      this.basis.address
    );
    const preb = await this.collateralManager.unallocatedCollateral(
      this.bob.address,
      this.basis.address
    );
    const treasuryBefore = await this.basis.balanceOf(this.owner.address);
    await spearmint(
      this.alice,
      this.bob,
      premium,
      true,
      this.TFM,
      this.owner,
      1234,
      this.eth,
      this.basis.address,
      this.basis.address,
      1,
      [[1, 10]],
      alphaCollateralRequirement,
      omegaCollateralRequirement,
      alphaFee,
      omegaFee
    );
    const posta = await this.collateralManager.unallocatedCollateral(
      this.alice.address,
      this.basis.address
    );
    const postb = await this.collateralManager.unallocatedCollateral(
      this.bob.address,
      this.basis.address
    );
    expect(posta).to.equal(
      prea - alphaCollateralRequirement - alphaFee - premium
    );
    expect(postb).to.equal(
      preb - omegaCollateralRequirement - omegaFee + premium
    );
    expect(
      await this.collateralManager.allocatedCollateral(this.alice.address, 0)
    ).to.equal(alphaCollateralRequirement);
    expect(
      await this.collateralManager.allocatedCollateral(this.bob.address, 0)
    ).to.equal(omegaCollateralRequirement);
    expect(await this.basis.balanceOf(this.owner.address)).to.equal(
      treasuryBefore.add(alphaFee).add(omegaFee)
    );
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
});
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
