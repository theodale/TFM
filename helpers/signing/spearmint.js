const { ethers } = require("hardhat");

const signSpearmint = async (
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

  return spearmintParameters;
};

module.exports = {
  signSpearmint,
};
