const { mintAndDeposit } = require("../collateral-management.js");
const { getMintTerms } = require("../terms/mint.js");
const { signSpearmint } = require("../signing/spearmint.js");

const spearmint = async (
  alpha,
  omega,
  TFM,
  CollateralManager,
  oracle,
  bra,
  ket,
  basis,
  premium,
  transferable,
  expiry,
  amplitude,
  phase,
  alphaCollateralRequirement,
  omegaCollateralRequirement,
  alphaFee,
  omegaFee
) => {
  // DEPOSIT MINTER COLLATERALS

  let alphaDeposit = alphaCollateralRequirement.add(alphaFee);
  let omegaDeposit = omegaCollateralRequirement.add(omegaFee);

  if (premium > 0) {
    alphaDeposit = alphaDeposit.add(premium);
    omegaDeposit = omegaDeposit.sub(premium);
  } else {
    omegaDeposit = omegaDeposit.add(premium);
    alphaDeposit = alphaDeposit.sub(premium);
  }

  // Post required collateral
  await mintAndDeposit(CollateralManager, basis, alpha, alphaDeposit);
  await mintAndDeposit(CollateralManager, basis, omega, omegaDeposit);

  // SPEARMINT

  const { oracleSignature, mintTerms } = await getMintTerms(
    TFM,
    oracle,
    expiry,
    alphaCollateralRequirement,
    omegaCollateralRequirement,
    alphaFee,
    omegaFee,
    bra,
    ket,
    basis,
    amplitude,
    phase
  );

  const { alphaSignature, omegaSignature } = await signSpearmint(
    alpha,
    omega,
    oracleSignature,
    premium,
    transferable,
    TFM
  );

  const mintParameters = {
    oracleSignature,
    alpha: alpha.address,
    omega: omega.address,
    premium,
    transferable,
  };

  const strategyId = await TFM.strategyCounter();

  const spearmintTransaction = await TFM.spearmint(
    mintTerms,
    mintParameters,
    alphaSignature,
    omegaSignature
  );

  return { strategyId, spearmintTransaction };
};

module.exports = {
  spearmint,
};
