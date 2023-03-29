const { mintAndDeposit } = require("../collateral-management.js");
const { getExerciseTerms } = require("../terms.js");

const exercise = async (
  TFM,
  CollateralManager,
  Basis,
  strategyId,
  alpha,
  omega,
  oracle,
  payout,
  alphaFee,
  omegaFee
) => {
  // PROVIDE COLLATERAL FOR FEE PAYMENTS

  await mintAndDeposit(CollateralManager, Basis, alpha, alphaFee);
  await mintAndDeposit(CollateralManager, Basis, omega, omegaFee);

  // EXERCISE

  const { exerciseTerms, oracleSignature } = await getExerciseTerms(
    TFM,
    oracle,
    strategyId,
    payout,
    alphaFee,
    omegaFee
  );

  const exerciseParameters = {
    oracleSignature,
    strategyId,
  };

  const exerciseTransaction = await TFM.exercise(
    exerciseTerms,
    exerciseParameters
  );

  return exerciseTransaction;
};

module.exports = {
  exercise,
};
