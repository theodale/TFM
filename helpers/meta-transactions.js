const { ethers } = require("hardhat");

const signSpearmintParameters = async (
  signer,
  trufinOracleSignature,
  alphaAddress,
  omegaAddress,
  premium,
  transferable,
  mintNonce
) => {
  const hash = ethers.utils.solidityKeccak256(
    ["bytes", "address", "address", "int256", "bool", "uint256", "uint8"],
    [
      trufinOracleSignature,
      alphaAddress,
      omegaAddress,
      premium,
      transferable,
      mintNonce,
      0,
    ]
  );

  const spearmintSignature = await signer.signMessage(
    ethers.utils.arrayify(hash)
  );

  const spearmintParameters = {
    trufinOracleSignature: trufinOracleSignature,
    alpha: alphaAddress,
    omega: omegaAddress,
    premium: premium,
    transferable: transferable,
    mintNonce: mintNonce,
  };

  return { spearmintSignature, spearmintParameters };
};

module.exports = {
  signSpearmintParameters,
};
