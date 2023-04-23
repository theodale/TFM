const { ethers } = require("hardhat");

const signCombination = async (
  combiner,
  TFM,
  strategyOneId,
  strategyTwoId,
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

  const signature = await combiner.signMessage(ethers.utils.arrayify(hash));

  return signature;
};

module.exports = {
  signCombination,
};
