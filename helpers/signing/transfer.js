const { ethers } = require("hardhat");

const signTransfer = async (
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
  signTransfer,
};
