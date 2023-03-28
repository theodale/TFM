const { ethers } = require("hardhat");

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

  return spearmintParameters;
};

const signTransferParameters = async (
  sender,
  recipient,
  staticParty,
  oracleSignature,
  strategyId,
  premium
) => {
  const message = ethers.utils.solidityKeccak256(
    ["bytes", "uint256", "address", "int256"],
    [oracleSignature, strategyId, recipient.address, premium]
  );

  const senderSignature = await sender.signMessage(
    ethers.utils.arrayify(message)
  );
  const recipientSignature = await recipient.signMessage(
    ethers.utils.arrayify(message)
  );
  const staticPartySignature = await staticParty.signMessage(
    ethers.utils.arrayify(message)
  );

  const transferParameters = {
    strategyId,
    recipient: recipient.address,
    premium,
    oracleSignature,
    senderSignature,
    recipientSignature,
    staticPartySignature,
  };

  return transferParameters;
};

module.exports = {
  signSpearmintParameters,
  signTransferParameters,
};