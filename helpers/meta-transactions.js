const { ethers } = require("hardhat");

// struct SpearmintTerms {
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

const signSpearmintParameters = async (
  alpha,
  omega,
  trufinOracleSignature,
  premium,
  transferable,
  TFM
) => {
  const mintNonce = await TFM.getMintNonce(alpha.address, omega.address);

  const hash = ethers.utils.solidityKeccak256(
    ["bytes", "address", "address", "int256", "bool", "uint256"],
    [
      trufinOracleSignature,
      alpha.address,
      omega.address,
      premium,
      transferable,
      mintNonce,
    ]
  );

  const alphaSignature = await alpha.signMessage(ethers.utils.arrayify(hash));
  const omegaSignature = await omega.signMessage(ethers.utils.arrayify(hash));

  const spearmintParameters = {
    oracleSignature: trufinOracleSignature,
    alpha: alpha.address,
    alphaSignature: alphaSignature,
    omega: omega.address,
    omegaSignature: omegaSignature,
    premium: premium,
    transferable: transferable,
  };

  return {
    alphaSignature,
    omegaSignature,
    spearmintParameters,
  };
};

module.exports = {
  signSpearmintParameters,
};
