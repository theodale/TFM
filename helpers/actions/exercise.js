const { getOracleExerciseSignature } = require("../oracle/exercise.js");

const exercise = async (TFM, strategyId, oracle, payout) => {
  const oracleSignature = await getOracleExerciseSignature(
    TFM,
    oracle,
    strategyId,
    payout
  );

  const oracleNonce = await TFM.oracleNonce();

  const exerciseParameters = {
    payout,
    oracleNonce,
    oracleSignature,
    strategyId,
  };

  const exerciseTransaction = await TFM.exercise(exerciseParameters);

  return exerciseTransaction;
};

module.exports = {
  exercise,
};
