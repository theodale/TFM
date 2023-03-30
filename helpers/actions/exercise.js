const { getExerciseTerms } = require("../terms/exercise");

const exercise = async (TFM, strategyId, oracle, payout) => {
  const { exerciseTerms, oracleSignature } = await getExerciseTerms(
    TFM,
    oracle,
    strategyId,
    payout
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
