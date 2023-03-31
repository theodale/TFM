const { ethers } = require("hardhat");

const signCombination = async (
  TFM,
  strategyOneId,
  strategyTwoId,
  strategyOneAlpha,
  strategyOneOmega,
  oracleSignature
) => {
  const strategyOne = await TFM.getStrategy(strategyOneId);
  const strategyTwo = await TFM.getStrategy(strategyTwoId);

  const hash = ethers.utils.solidityKeccak256(
    ["uint256", "uint256", "uint256", "uint256", "bytes"],
    [
      strategyOneId,
      strategyTwoId,
      strategyOne.actionNonce,
      strategyTwo.actionNonce,
      oracleSignature,
    ]
  );

  const strategyOneAlphaSignature = await strategyOneAlpha.signMessage(
    ethers.utils.arrayify(hash)
  );
  const strategyOneOmegaSignature = await strategyOneOmega.signMessage(
    ethers.utils.arrayify(hash)
  );

  const combinationParameters = {
    strategyOneId,
    strategyTwoId,
    strategyOneAlphaSignature,
    strategyOneOmegaSignature,
    oracleSignature,
  };

  return combinationParameters;
};

module.exports = {
  signCombination,
};
