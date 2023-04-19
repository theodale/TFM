const { ethers } = require("hardhat");

const getTransferTerms = async (
  TFM,
  strategyId,
  oracle,
  recipientCollateralRequirement,
  senderFee,
  recipientFee,
  alphaTransfer
) => {
  const oracleNonce = await TFM.oracleNonce();

  const strategy = await TFM.getStrategy(strategyId);

  const hash = ethers.utils.solidityKeccak256(
    [
      "uint48",
      "address",
      "address",
      "address",
      "uint256",
      "int256[2][]",
      "uint256",
      "uint256",
      "uint256",
      "bool",
      "uint256",
    ],
    [
      strategy.expiry,
      strategy.bra,
      strategy.ket,
      strategy.basis,
      strategy.amplitude,
      strategy.phase,
      senderFee,
      recipientFee,
      recipientCollateralRequirement,
      alphaTransfer,
      oracleNonce,
    ]
  );

  const oracleSignature = await oracle.signMessage(ethers.utils.arrayify(hash));

  const transferTerms = {
    recipientCollateralRequirement,
    oracleNonce,
    senderFee,
    recipientFee,
    alphaTransfer,
  };

  return { oracleSignature, transferTerms };
};

module.exports = {
  getTransferTerms,
};
