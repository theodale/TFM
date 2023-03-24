const { ethers } = require("hardhat");

const { generateSpearmintTerms } = require("./terms.js");
const { signSpearmintParameters } = require("./meta-transactions.js");

// truct SpearmintTerms {
//   uint256 expiry;
//   uint256 alphaCollateralRequirement;
//   uint256 omegaCollateralRequirement;
//   uint256 alphaFee;
//   uint256 omegaFee;
//   uint256 oracleNonce;
//   address bra;
//   address ket;
//   address basis;
//   int256 amplitude;
//   int256[2][] phase;
// }

// struct SpearmintParameters {
//   // Links to a specific set of spearmint terms
//   bytes oracleSignature;
//   address alpha;
//   bytes alphaSignature;
//   address omega;
//   bytes omegaSignature;
//   int256 premium;
//   bool transferable;
// }

const spearmint = async (
  alpha,
  omega,
  premium,
  transferable,
  TFM,
  oracle,
  expiry,
  bra,
  ket,
  basis,
  amplitude,
  phase,
  alphaCollateralRequirement,
  omegaCollateralRequirement,
  alphaFee,
  omegaFee
) => {
  const oracleNonce = await TFM.oracleNonce();

  const { trufinOracleSignature, spearMintTerms } =
    await generateSpearmintTerms(
      oracle,
      expiry,
      alphaCollateralRequirement,
      omegaCollateralRequirement,
      alphaFee,
      omegaFee,
      oracleNonce,
      bra,
      ket,
      basis,
      amplitude,
      phase
    );

  const { alphaSignature, omegaSignature, spearmintParameters } =
    await signSpearmintParameters(
      alpha,
      omega,
      trufinOracleSignature,
      premium,
      transferable,
      TFM
    );

  const strategyId = await TFM.strategyCounter();

  await TFM.spearmint(spearMintTerms, spearmintParameters);

  return strategyId;
};

module.exports = {
  spearmint,
};
