const { ethers } = require("hardhat");

const signSpearmint = async (
  spearminter,
  alpha,
  omega,
  TFM,
  oracleSignature,
  premium,
  transferable
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

  const signature = await spearminter.signMessage(ethers.utils.arrayify(hash));

  return signature;
};

module.exports = {
  signSpearmint,
};
