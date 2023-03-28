const { expect } = require("chai");
const { ethers } = require("hardhat");
const { testDeployment } = require("../helpers/fixtures.js");
const { spearmint } = require("../helpers/actions.js");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { zeroState, depositState } = require("../helpers/utils.js");
const { PANIC_CODES } = require("@nomicfoundation/hardhat-chai-matchers/panic");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const { SPEARMINT_TEST_PARAMETERS_1 } = require("./test-parameters.js");
const { signSpearmintParameters } = require("../helpers/meta-transactions.js");
const { generateSpearmintTerms } = require("../helpers/terms.js");
const { mintAndDeposit } = require("../helpers/collateral-management.js");
const {setNonce} = require("../helpers/setOracleNonce.js")

describe("SPEARMINT", () => {
  beforeEach(async () => {
    ({
      TFM: this.TFM,
      CollateralManager: this.CollateralManager,
      BRA: this.BRA,
      KET: this.KET,
      Basis: this.Basis,
      Utils: this.Utils,
      oracle: this.oracle,
      owner: this.owner,
      alice: this.alice,
      bob: this.bob,
    } = await loadFixture(testDeployment));
  });

  describe("Simple Valid Spearmint", () => {
    beforeEach(async () => {
      this.strategyId = this.strategyId = await spearmint(
        this.alice,
        this.bob,
        this.TFM,
        this.CollateralManager,
        this.oracle,
        this.BRA,
        this.KET,
        this.Basis,
        SPEARMINT_TEST_PARAMETERS_1
      );
      if(SPEARMINT_TEST_PARAMETERS_1.premium > 0){this.alphaDeposit = SPEARMINT_TEST_PARAMETERS_1.alphaCollateralRequirement
        .add(SPEARMINT_TEST_PARAMETERS_1.alphaFee)
        .add(SPEARMINT_TEST_PARAMETERS_1.premium);
      this.omegaDeposit =
        SPEARMINT_TEST_PARAMETERS_1.omegaCollateralRequirement.add(
          SPEARMINT_TEST_PARAMETERS_1.omegaFee
        );}
      else{this.alphaDeposit = SPEARMINT_TEST_PARAMETERS_1.alphaCollateralRequirement
        .add(SPEARMINT_TEST_PARAMETERS_1.alphaFee)
      this.omegaDeposit =
        SPEARMINT_TEST_PARAMETERS_1.omegaCollateralRequirement.add(
          SPEARMINT_TEST_PARAMETERS_1.omegaFee
        ).add((SPEARMINT_TEST_PARAMETERS_1.premium).mul(-1));}
      this.alphaPersonalPool = await this.CollateralManager.personalPools(
        this.alice.address
      );
      this.omegaPersonalPool = await this.CollateralManager.personalPools(
        this.bob.address
      );
    });

    it("Should have correct strategy parameters post-mint", async () => {
      const strategy = await this.TFM.getStrategy(this.strategyId);

      // Strategy state
      expect(strategy.alpha).to.equal(this.alice.address);
      expect(strategy.omega).to.equal(this.bob.address);
      expect(strategy.transferable).to.equal(
        SPEARMINT_TEST_PARAMETERS_1.transferable
      );
      expect(strategy.expiry).to.equal(SPEARMINT_TEST_PARAMETERS_1.expiry);
      expect(strategy.amplitude).to.equal(
        SPEARMINT_TEST_PARAMETERS_1.amplitude
      );
      expect(strategy.bra).to.equal(this.BRA.address);
      expect(strategy.ket).to.equal(this.KET.address);
      expect(strategy.basis).to.equal(this.Basis.address);
      expect(strategy.actionNonce).to.equal(0);
      expect(strategy.phase).to.deep.equal(SPEARMINT_TEST_PARAMETERS_1.phase);
    });

    it("Should have the correct collateral state post-mint", async () => {
      // correct allocated collateral
      expect(
        await this.CollateralManager.allocatedCollateral(
          this.alice.address,
          this.strategyId
        )
      ).to.equal(SPEARMINT_TEST_PARAMETERS_1.alphaCollateralRequirement);
      expect(
        await this.CollateralManager.allocatedCollateral(
          this.bob.address,
          this.strategyId
        )
      ).to.equal(SPEARMINT_TEST_PARAMETERS_1.omegaCollateralRequirement);

      //correct unallocated collateral depending on if premium is positive or negative
      if (SPEARMINT_TEST_PARAMETERS_1.premium > 0) {
        expect(
          await this.CollateralManager.unallocatedCollateral(
            this.alice.address,
            this.Basis.address
          )
        ).to.equal(0);
        expect(
          await this.CollateralManager.unallocatedCollateral(
            this.bob.address,
            this.Basis.address
          )
        ).to.equal(SPEARMINT_TEST_PARAMETERS_1.premium);
      } else {
        expect(
          await this.CollateralManager.unallocatedCollateral(
            this.bob.address,
            this.Basis.address
          )
        ).to.equal(0);
        expect(
          await this.CollateralManager.unallocatedCollateral(
            this.alice.address,
            this.Basis.address
          )
        ).to.equal(SPEARMINT_TEST_PARAMETERS_1.premium.mul(-1));
      }

      //Correct fees sent to treasury
      expect(await this.Basis.balanceOf(this.owner.address)).to.equal(
        SPEARMINT_TEST_PARAMETERS_1.alphaFee.add(
          SPEARMINT_TEST_PARAMETERS_1.omegaFee
        )
      );
      expect(await this.Basis.balanceOf(this.alice.address)).to.equal(0);
    });

    //check personal pool balance post spearmint
    it("Should have correct personalPool balances post-mint", async () => {
      expect(await this.Basis.balanceOf(this.omegaPersonalPool)).to.equal(
        //if premium is positive, omega gets it
        this.omegaDeposit
          .add(SPEARMINT_TEST_PARAMETERS_1.premium) 
          .sub(SPEARMINT_TEST_PARAMETERS_1.omegaFee)
      );
      //if premium is negative, alpha gets it
      expect(await this.Basis.balanceOf(this.alphaPersonalPool)).to.equal(
        this.alphaDeposit
          .sub(SPEARMINT_TEST_PARAMETERS_1.premium)
          .sub(SPEARMINT_TEST_PARAMETERS_1.alphaFee)
      );
    });
  });


  describe("Signature authentication", () => {
    beforeEach(async () => {
      this.nonce = await this.TFM.oracleNonce();
      //build spearmint manually
      this.res = await generateSpearmintTerms(
        this.oracle,
        SPEARMINT_TEST_PARAMETERS_1.expiry,
        SPEARMINT_TEST_PARAMETERS_1.alphaCollateralRequirement,
        SPEARMINT_TEST_PARAMETERS_1.omegaCollateralRequirement,
        SPEARMINT_TEST_PARAMETERS_1.alphaFee,
        SPEARMINT_TEST_PARAMETERS_1.omegaFee,
        this.nonce,
        this.BRA,
        this.KET,
        this.Basis,
        SPEARMINT_TEST_PARAMETERS_1.amplitude,
        SPEARMINT_TEST_PARAMETERS_1.phase
      );

      this.sp = await signSpearmintParameters(
        this.alice,
        this.bob,
        this.res.oracleSignature,
        SPEARMINT_TEST_PARAMETERS_1.premium,
        SPEARMINT_TEST_PARAMETERS_1.transferable,
        this.TFM
      );
    });

    it("should revert with wrong oracle signature", async () => {
      //send in alice as oracle
      await expect(
        spearmint(
          this.alice,
          this.bob,
          this.TFM,
          this.CollateralManager,
          this.alice,
          this.BRA,
          this.KET,
          this.Basis,
          SPEARMINT_TEST_PARAMETERS_1
        )
      ).to.be.revertedWith("SPEARMINT: Invalid Trufin oracle signature");
    });

    it("should revert with wrong signature parameters", async () => {
      //change alphaCollateralRequirement to 0
      this.res.spearmintTerms.alphaCollateralRequirement =
        ethers.utils.parseEther("0");
      await expect(
        this.TFM.spearmint(this.res.spearmintTerms, this.sp)
      ).to.be.revertedWith("SPEARMINT: Invalid Trufin oracle signature");
    });

    it("should revert with no posted collateral", async () => {
      //post no collateral
      await expect(
        this.TFM.spearmint(this.res.spearmintTerms, this.sp)
      ).to.be.revertedWithPanic(0x11);
    });

    it("should revert if alpha/omega signature is wrong", async () => {
      //change transferable to false, which invalidates signatures
      this.sp.transferable = false;
      await expect(
        this.TFM.spearmint(this.res.spearmintTerms, this.sp)
      ).to.be.revertedWith("SPEARMINT: Alpha signature invalid");
    });
  });


  describe("Nonces and Events", () => {
    beforeEach(async () => {
      this.nonce = await this.TFM.oracleNonce();
      this.res = await generateSpearmintTerms(
        this.oracle,
        SPEARMINT_TEST_PARAMETERS_1.expiry,
        SPEARMINT_TEST_PARAMETERS_1.alphaCollateralRequirement,
        SPEARMINT_TEST_PARAMETERS_1.omegaCollateralRequirement,
        SPEARMINT_TEST_PARAMETERS_1.alphaFee,
        SPEARMINT_TEST_PARAMETERS_1.omegaFee,
        this.nonce,
        this.BRA,
        this.KET,
        this.Basis,
        SPEARMINT_TEST_PARAMETERS_1.amplitude,
        SPEARMINT_TEST_PARAMETERS_1.phase
      );

      this.sp = await signSpearmintParameters(
        this.alice,
        this.bob,
        this.res.oracleSignature,
        SPEARMINT_TEST_PARAMETERS_1.premium,
        SPEARMINT_TEST_PARAMETERS_1.transferable,
        this.TFM
      );
      //calculate deposit amounts to mintAndDeposit
      this.alphaDeposit =
        SPEARMINT_TEST_PARAMETERS_1.alphaCollateralRequirement.add(
          SPEARMINT_TEST_PARAMETERS_1.alphaFee
        );
      this.omegaDeposit =
        SPEARMINT_TEST_PARAMETERS_1.omegaCollateralRequirement.add(
          SPEARMINT_TEST_PARAMETERS_1.omegaFee
        );
      if (SPEARMINT_TEST_PARAMETERS_1.premium > 0) {
        this.alphaDeposit = this.alphaDeposit.add(
          SPEARMINT_TEST_PARAMETERS_1.premium
        );
      } else {
        this.omegaDeposit = this.omegaDeposit.add(
          SPEARMINT_TEST_PARAMETERS_1.premium.mul(-1)
        );
      }
      await mintAndDeposit(
        this.CollateralManager,
        this.Basis,
        this.alice,
        this.alphaDeposit.mul(2)
      );
      await mintAndDeposit(
        this.CollateralManager,
        this.Basis,
        this.bob,
        this.omegaDeposit.mul(2)
      );
    });

    it("should revert if same mintNonce is used", async () => {
      //send same transaction twice
      await this.TFM.spearmint(this.res.spearmintTerms, this.sp);
      await expect(
        this.TFM.spearmint(this.res.spearmintTerms, this.sp)
      ).to.be.revertedWith("SPEARMINT: Alpha signature invalid");
      const mn = await this.TFM.getMintNonce(
        this.alice.address,
        this.bob.address
      );
      expect(mn).to.equal(1);
    });

    it("should emit an event when a strategy is minted", async () => {
      //checks whether event with strategyID is emitted
      await expect(this.TFM.spearmint(this.res.spearmintTerms, this.sp))
        .to.emit(this.TFM, "Spearmint")
        .withArgs(0);
    });

    it("should revert if nonce hasn't been updated in a while", async () => {
      //jump forward to blocktime + 2 hours where nonce will be outdated
      await time.increase(7200);
      await expect(
        this.TFM.spearmint(this.res.spearmintTerms, this.sp)
      ).to.be.revertedWith(
        "TFM: Contract locked due as oracle nonce has not been updated"
      );
    });

    it("should revert if nonce is outdated", async () => {
      //create new spearmint requirements with wrong nonce (i.e. 5)
      this.res1 = await generateSpearmintTerms(
        this.oracle,
        SPEARMINT_TEST_PARAMETERS_1.expiry,
        SPEARMINT_TEST_PARAMETERS_1.alphaCollateralRequirement,
        SPEARMINT_TEST_PARAMETERS_1.omegaCollateralRequirement,
        SPEARMINT_TEST_PARAMETERS_1.alphaFee,
        SPEARMINT_TEST_PARAMETERS_1.omegaFee,
        5,
        this.BRA,
        this.KET,
        this.Basis,
        SPEARMINT_TEST_PARAMETERS_1.amplitude,
        SPEARMINT_TEST_PARAMETERS_1.phase
      );
      this.sp1 = await signSpearmintParameters(
        this.alice,
        this.bob,
        this.res1.oracleSignature,
        SPEARMINT_TEST_PARAMETERS_1.premium,
        SPEARMINT_TEST_PARAMETERS_1.transferable,
        this.TFM
      );
      await expect(
        this.TFM.spearmint(this.res1.spearmintTerms, this.sp1)
      ).to.be.revertedWith("TFM: Oracle nonce has expired");
    });

    it("should allow updating the oracleNonce", async() => {
      this.oracleSig = await setNonce(this.TFM,this.oracle,2)
      await expect(this.TFM.updateOracleNonce(2,this.oracleSig)).to.emit(this.TFM,"OracleNonceUpdated").withArgs(2)
      await expect(this.TFM.spearmint(this.res.spearmintTerms,this.sp)).to.be.revertedWith("TFM: Oracle nonce has expired")
      await expect(this.TFM.updateOracleNonce(1,this.oracleSig)).to.be.revertedWith("TFM: Oracle nonce can only be increased")
    })
  });

  //this.sp1 = await signSpearmintParameters(
//   this.alice,
//   this.bob,
//   this.res.oracleSignature,
//   SPEARMINT_TEST_PARAMETERS_1.premium,
//   SPEARMINT_TEST_PARAMETERS_1.transferable,
//   this.TFM
// );
// await this.TFM.spearmint(this.res.spearmintTerms, this.sp1);
// const mn2 = await this.TFM.getMintNonce(
//   this.alice.address,
//   this.bob.address
// );
// expect(mn2).to.equal(2);
  // it("should correctly increase strategy and mintNonce counters", async () => {
  //   await this.TFM.spearmint(res.spearMintTerms, sp.spearmintParameters);

  //   const strategyId = await this.TFM.strategyCounter();
  //   expect(strategyId).to.equal(1);
  //   await spearmint(
  //     this.alice,
  //     this.bob,
  //     premium,
  //     false,
  //     this.TFM,
  //     this.owner,
  //     1234,
  //     this.eth,
  //     this.basis.address,
  //     this.basis.address,
  //     1,
  //     [[1, 10]],
  //     alphaCollateralRequirement,
  //     omegaCollateralRequirement,
  //     alphaFee,
  //     omegaFee
  //   );
  //   const strategyId2 = await this.TFM.strategyCounter();
  //   expect(strategyId2).to.equal(2);
  //   let mintNonce = await this.TFM.getMintNonce(
  //     this.alice.address,
  //     this.bob.address
  //   );
  //   expect(mintNonce).to.equal(2);
  //   const oracleNonce = await this.TFM.oracleNonce();
  //   const res1 = await generateSpearmintTerms(
  //     this.owner,
  //     16273919,
  //     200,
  //     90,
  //     1,
  //     4,
  //     oracleNonce,
  //     this.eth,
  //     this.basis.address,
  //     this.basis.address,
  //     2000000,
  //     [[2000000, 14000000]]
  //   );

  //   const sp1 = await signSpearmintParameters(
  //     this.alice,
  //     this.bob,
  //     res1.trufinOracleSignature,
  //     this.alice.address,
  //     this.bob.address,
  //     100,
  //     true,
  //     mintNonce
  //   );

  //   await expect(
  //     this.TFM.spearmint(res1.spearMintTerms, sp1.spearmintParameters)
  //   )
  //     .to.emit(this.TFM, "Spearmint")
  //     .withArgs(2);
  // });

  
});
