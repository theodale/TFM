const { mintAndDeposit } = require("../collateral-management.js");
const { getSpearmintTerms } = require("../terms/spearmint.js");
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

  const { oracleSignature, spearmintTerms } = await getSpearmintTerms(
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

  const spearmintParameters = await signSpearmint(
    alpha,
    omega,
    oracleSignature,
    premium,
    transferable,
    TFM
  );

  const strategyId = await TFM.strategyCounter();

  const spearmintTransaction = await TFM.spearmint(
    spearmintTerms,
    spearmintParameters
  );

  return { strategyId, spearmintTransaction };
};

module.exports = {
  spearmint,
};
