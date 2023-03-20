const { ethers } = require("hardhat");

const { generateSpearmintDataPackage } = require("./data-packages.js");
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

  const { trufinOracleSignature, spearmintDataPackage } =
    await generateSpearmintDataPackage(
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

  const { spearmintSignature: alphaSignature, spearmintParameters } =
    await signSpearmintParameters(
      alpha,
      trufinOracleSignature,
      alpha.address,
      omega.address,
      premium,
      transferable,
      mintNonce
    );

  const { spearmintSignature: omegaSignature } = await signSpearmintParameters(
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
    spearmintDataPackage,
    spearmintParameters,
    alphaSignature,
    omegaSignature
  );

  return strategyId;
};

module.exports = {
  spearmint,
};
