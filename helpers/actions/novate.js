const { mintAndDeposit } = require("../utils.js");
const { getOracleNovationSignature } = require("../oracle/novation.js");
const { signNovation } = require("../signing/novation.js");

const novate = async (
  ActionLayer,
  AssetLayer,
  Basis,
  strategyOneId,
  strategyTwoId,
  middleParty,
  strategyOneNonMiddleParty,
  strategyTwoNonMiddleParty,
  oracle,
  strategyOneResultingAlphaCollateralRequirement,
  strategyOneResultingOmegaCollateralRequirement,
  strategyTwoResultingAlphaCollateralRequirement,
  strategyTwoResultingOmegaCollateralRequirement,
  strategyOneResultingAmplitude,
  strategyTwoResultingAmplitude,
  fee
) => {
  await mintAndDeposit(middleParty, fee, Basis, AssetLayer);

  const oracleSignature = await getOracleNovationSignature(
    ActionLayer,
    oracle,
    strategyOneId,
    strategyTwoId,
    strategyOneResultingAlphaCollateralRequirement,
    strategyOneResultingOmegaCollateralRequirement,
    strategyTwoResultingAlphaCollateralRequirement,
    strategyTwoResultingOmegaCollateralRequirement,
    strategyOneResultingAmplitude,
    strategyTwoResultingAmplitude,
    fee
  );

  //   bytes middlePartySignature;
  //   // These signatures below are not used if their respective strategy is transferable
  //   bytes strategyOneNonMiddlePartySignature;
  //   bytes strategyTwoNonMiddlePartySignature;

  //   const middlePartySignature = await signNovation(middleParty);

  const oracleNonce = await ActionLayer.oracleNonce();

  //   const strategyOne = await TFM.getStrategy(strategyOneId);
  //   const strategyTwo = await TFM.getStrategy(strategyTwoId);

  const novationParameters = [
    strategyOneId,
    strategyTwoId,
    oracleSignature,
    "0x00",
    "0x00",
    "0x00",
    oracleNonce,
    strategyOneResultingAlphaCollateralRequirement,
    strategyOneResultingOmegaCollateralRequirement,
    strategyTwoResultingAlphaCollateralRequirement,
    strategyTwoResultingOmegaCollateralRequirement,
    strategyOneResultingAmplitude,
    strategyTwoResultingAmplitude,
    fee,
  ];

  const novationTransaction = await ActionLayer.novate(novationParameters);

  return novationTransaction;
};

module.exports = {
  novate,
};
