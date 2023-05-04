const { ethers } = require("hardhat");

// sign strategy IDs
const signNovation = async (novator, ActionLayer, oracleSignature) => {
  //   const hash = ethers.utils.solidityKeccak256(
  //     ["bytes", "address", "address", "int256", "bool", "uint256"],
  //     [
  //       oracleSignature,
  //       alpha.address,
  //       omega.address,
  //       premium,
  //       transferable,
  //       mintNonce,
  //     ]
  //   );

  const signature = await spearminter.signMessage(ethers.utils.arrayify(hash));

  return signature;
};

module.exports = {
  signNovation,
};
