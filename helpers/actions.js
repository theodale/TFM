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

  const { oracleSignature, spearmintTerms } = await generateSpearmintTerms(
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

  const spearmintParameters = await signSpearmintParameters(
    alpha,
    omega,
    oracleSignature,
    premium,
    transferable,
    TFM
  );

  const strategyId = await TFM.strategyCounter();

  await TFM.spearmint(spearmintTerms, spearmintParameters);

  return strategyId;
};

module.exports = {
  spearmint,
};
