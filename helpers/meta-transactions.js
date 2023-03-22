const { ethers } = require("hardhat");

const signSpearmintParameters = async (
  alphaSigner,
  omegaSigner,
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

  const spearmintSignatureA = await alphaSigner.signMessage(
    ethers.utils.arrayify(hash)
  );
  const spearmintSignatureO = await omegaSigner.signMessage(
    ethers.utils.arrayify(hash)
  );
  const spearmintParameters = {
    trufinOracleSignature: trufinOracleSignature,
    alpha: alphaAddress,
    omega: omegaAddress,
    alphaSignature: spearmintSignatureA,
    omegaSignature:spearmintSignatureO,
    premium: premium,
    transferable: transferable,
    mintNonce: mintNonce,
  };

  return { spearmintSignature, spearmintParameters };
};

module.exports = {
  signSpearmintParameters,
};
