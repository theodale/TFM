const { ethers } = require("hardhat");

const getExerciseTerms = async (TFM, oracle, strategyId, payout) => {
  const oracleNonce = await TFM.oracleNonce();

  const strategy = await TFM.getStrategy(strategyId);

  const hash = ethers.utils.solidityKeccak256(
    [
      "uint256",
      "address",
      "address",
      "address",
      "int256",
      "int256[2][]",
      "uint256",
      "int256",
    ],
    [
      strategy.expiry,
      strategy.bra,
      strategy.ket,
      strategy.basis,
      strategy.amplitude,
      strategy.phase,
      oracleNonce,
      payout,
    ]
  );

  const oracleSignature = await oracle.signMessage(ethers.utils.arrayify(hash));

  const exerciseTerms = {
    payout,
    oracleNonce,
  };

  return { oracleSignature, exerciseTerms };
};

module.exports = {
  getExerciseTerms,
};
