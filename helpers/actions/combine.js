const { mintAndDeposit } = require("../utils.js");
const { getOracleCombinationSignature } = require("../oracle/combination.js");
const { signCombination } = require("../signing/combination.js");

const combine = async (
  TFM,
  FundManager,
  Basis,
  strategyOneId,
  strategyTwoId,
  alphaOne,
  omegaOne,
  oracle,
  alphaOneFee,
  omegaOneFee,
  resultingAlphaCollateralRequirement,
  resultingOmegaCollateralRequirement,
  resultingPhase,
  resultingAmplitude
) => {
  await mintAndDeposit(
    alphaOne,
    alphaOneFee.add(resultingAlphaCollateralRequirement),
    Basis,
    FundManager
  );
  await mintAndDeposit(
    omegaOne,
    omegaOneFee.add(resultingOmegaCollateralRequirement),
    Basis,
    FundManager
  );

  const oracleSignature = await getOracleCombinationSignature(
    TFM,
    oracle,
    strategyOneId,
    strategyTwoId,
    alphaOneFee,
    omegaOneFee,
    resultingAlphaCollateralRequirement,
    resultingOmegaCollateralRequirement,
    resultingPhase,
    resultingAmplitude
  );

  const alphaOneSignature = await signCombination(
    alphaOne,
    TFM,
    strategyOneId,
    strategyTwoId,
    oracleSignature
  );
  const omegaOneSignature = await signCombination(
    omegaOne,
    TFM,
    strategyOneId,
    strategyTwoId,
    oracleSignature
  );

  const oracleNonce = await TFM.oracleNonce();

  const strategyOne = await TFM.getStrategy(strategyOneId);
  const strategyTwo = await TFM.getStrategy(strategyTwoId);

  const aligned = strategyOne.alpha == strategyTwo.alpha;

  const combinationParameters = [
    alphaOneFee,
    omegaOneFee,
    resultingAlphaCollateralRequirement,
    resultingOmegaCollateralRequirement,
    resultingAmplitude,
    resultingPhase,
    oracleNonce,
    aligned,
    strategyOneId,
    strategyTwoId,
    alphaOneSignature,
    omegaOneSignature,
    oracleSignature,
  ];

  const combinationTransaction = await TFM.combine(combinationParameters);

  return combinationTransaction;
};

module.exports = {
  combine,
};
