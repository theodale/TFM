const { ethers } = require("hardhat");

const { generateSpearmintTerms } = require("./terms.js");
const { signSpearmintParameters } = require("./meta-transactions.js");
const { mintAndDeposit } = require("../helpers/collateral-management.js");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

const spearmint = async (
  alpha,
  omega,
  TFM,
  CollateralManager,
  oracle,
  bra,
  ket,
  basis,
  testParameters
) => {
  // DEPOSIT MINTER COLLATERALS

  let alphaDeposit = testParameters.alphaCollateralRequirement.add(
    testParameters.alphaFee
  );
  let omegaDeposit = testParameters.omegaCollateralRequirement.add(
    testParameters.omegaFee
  );

  if (testParameters.premium > 0) {
    alphaDeposit = alphaDeposit.add(testParameters.premium);
  } else {
    omegaDeposit = omegaDeposit.add(testParameters.premium.mul(-1));
  }

  // Post required collateral
  await mintAndDeposit(CollateralManager, basis, alpha, alphaDeposit);
  await mintAndDeposit(CollateralManager, basis, omega, omegaDeposit);

  // SPEARMINT

  const oracleNonce = await TFM.oracleNonce();

  const { oracleSignature, spearmintTerms } = await generateSpearmintTerms(
    oracle,
    testParameters.expiry,
    testParameters.alphaCollateralRequirement,
    testParameters.omegaCollateralRequirement,
    testParameters.alphaFee,
    testParameters.omegaFee,
    oracleNonce,
    bra,
    ket,
    basis,
    testParameters.amplitude,
    testParameters.phase
  );

  const spearmintParameters = await signSpearmintParameters(
    alpha,
    omega,
    oracleSignature,
    testParameters.premium,
    testParameters.transferable,
    TFM
  );

  const strategyId = await TFM.strategyCounter();

  await TFM.spearmint(spearmintTerms, spearmintParameters);

  return strategyId;
};

module.exports = {
  spearmint,
};
