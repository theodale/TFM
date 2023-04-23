const { getOracleLiquidationSignature } = require("../oracle/liquidate.js");

const liquidate = async (
  TFM,
  FundManager,
  oracle,
  liquidator,
  strategyId,
  compensation,
  alphaPenalisation,
  omegaPenalisation,
  postLiquidationAmplitude
) => {
  const oracleSignature = await getOracleLiquidationSignature(
    TFM,
    FundManager,
    oracle,
    strategyId,
    compensation,
    alphaPenalisation,
    omegaPenalisation,
    postLiquidationAmplitude
  );

  const oracleNonce = await TFM.oracleNonce();

  const liquidationParameters = {
    oracleNonce,
    compensation,
    alphaPenalisation,
    omegaPenalisation,
    postLiquidationAmplitude,
    strategyId,
    oracleSignature,
  };

  const liquidateTransaction = await TFM.connect(liquidator).liquidate(
    liquidationParameters
  );

  return liquidateTransaction;
};

module.exports = {
  liquidate,
};
