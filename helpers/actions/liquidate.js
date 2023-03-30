const { getLiquidationTerms } = require("../terms/liquidate");

const liquidate = async (
  TFM,
  CollateralManager,
  oracle,
  liquidator,
  strategyId,
  compensation,
  alphaFee,
  omegaFee,
  postLiquidationAmplitude
) => {
  const { oracleSignature, liquidationTerms } = await getLiquidationTerms(
    TFM,
    CollateralManager,
    oracle,
    strategyId,
    compensation,
    alphaFee,
    omegaFee,
    postLiquidationAmplitude
  );

  const liquidationParameters = {
    oracleSignature,
    strategyId,
  };

  const liquidateTransaction = await TFM.connect(liquidator).liquidate(
    liquidationTerms,
    liquidationParameters
  );

  return liquidateTransaction;
};

module.exports = {
  liquidate,
};
