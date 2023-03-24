const { ethers } = require("hardhat");

const { generateSpearmintTerms } = require("./terms.js");
const { signSpearmintParameters } = require("./meta-transactions.js");

const spearmint = async (
  alpha,
  omega,
  premium,
  transferable,
  TFM,
  oracle,
  expiry,
  bra,
  ket,
  basis,
  amplitude,
  phase,
  alphaCollateralRequirement,
  omegaCollateralRequirement,
  alphaFee,
  omegaFee
) => {
  const oracleNonce = await TFM.oracleNonce();

  const { trufinOracleSignature, spearMintTerms} =
    await generateSpearmintTerms(
      oracle,
      expiry,
      alphaCollateralRequirement,
      omegaCollateralRequirement,
      alphaFee,
      omegaFee,
      oracleNonce,
      bra,
      ket,
      basis,
      amplitude,
      phase
    );
  const mintNonce = await TFM.getMintNonce(alpha.address, omega.address);
  const {alphaSignature, omegaSignature, spearmintParameters } =
    await signSpearmintParameters(
      alpha,
      omega,
      trufinOracleSignature,
      alpha.address,
      omega.address,
      premium,
      transferable,
      mintNonce
    );
  const strategyId = await TFM.strategyCounter();
  await TFM.spearmint(
    spearMintTerms,
    spearmintParameters
  );
  return strategyId
};

module.exports = {
  spearmint,
};
