const { ethers } = require("hardhat");

const signTransfer = async (
  signer,
  recipient,
  oracleSignature,
  strategyId,
  premium,
  TFM
) => {
  const strategy = await TFM.getStrategy(strategyId);

  const message = ethers.utils.solidityKeccak256(
    ["bytes", "uint256", "address", "int256", "uint256"],
    [
      oracleSignature,
      strategyId,
      recipient.address,
      premium,
      strategy.actionNonce,
    ]
  );

  const signature = await signer.signMessage(ethers.utils.arrayify(message));

  return signature;
};

module.exports = {
  signTransfer,
};
