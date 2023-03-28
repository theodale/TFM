const { ethers } = require("hardhat");

const setNonce = async (TFM, oracle, nonce) => {
  const hash = ethers.utils.solidityKeccak256(["uint256"], [nonce]);

  const oracleSignature = await oracle.signMessage(ethers.utils.arrayify(hash));

  return oracleSignature;
};

module.exports = {
  setNonce,
};
