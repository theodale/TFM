const { ethers } = require("hardhat");

const signSpearmint = async (
  alpha,
  omega,
  oracleSignature,
  premium,
  transferable,
  TFM
) => {
  const mintNonce = await TFM.getMintNonce(alpha.address, omega.address);

  const hash = ethers.utils.solidityKeccak256(
    ["bytes", "address", "address", "int256", "bool", "uint256"],
    [
      oracleSignature,
      alpha.address,
      omega.address,
      premium,
      transferable,
      mintNonce,
    ]
  );

  const alphaSignature = await alpha.signMessage(ethers.utils.arrayify(hash));
  const omegaSignature = await omega.signMessage(ethers.utils.arrayify(hash));

  return { alphaSignature, omegaSignature };
};

module.exports = {
  signSpearmint,
};
