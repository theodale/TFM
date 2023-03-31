const { mintAndDeposit } = require("../collateral-management.js");
const { getCombinationTerms } = require("../terms/combination.js");
const { signCombination } = require("../signing/combination.js");

const combine = async (
  TFM,
  CollateralManager,
  Basis,
  strategyOneId,
  strategyTwoId,
  strategyOneAlpha,
  strategyOneOmega,
  oracle,
  strategyOneAlphaFee,
  strategyOneOmegaFee,
  resultingAlphaCollateralRequirement,
  resultingOmegaCollateralRequirement,
  resultingPhase,
  resultingAmplitude
) => {
  // Cover combiners fees

  // Post required collateral
  await mintAndDeposit(
    CollateralManager,
    Basis,
    strategyOneAlpha,
    strategyOneAlphaFee
  );
  await mintAndDeposit(
    CollateralManager,
    Basis,
    strategyOneOmega,
    strategyOneOmegaFee
  );

  // COMBINE

  const { combinationTerms, oracleSignature } = await getCombinationTerms(
    TFM,
    oracle,
    strategyOneId,
    strategyTwoId,
    strategyOneAlphaFee,
    strategyOneOmegaFee,
    resultingAlphaCollateralRequirement,
    resultingOmegaCollateralRequirement,
    resultingPhase,
    resultingAmplitude
  );

  const combinationParameters = await signCombination(
    TFM,
    strategyOneId,
    strategyTwoId,
    strategyOneAlpha,
    strategyOneOmega,
    oracleSignature
  );

  const combinationTransaction = await TFM.combine(
    combinationTerms,
    combinationParameters
  );

  return combinationTransaction;
};

module.exports = {
  combine,
};
