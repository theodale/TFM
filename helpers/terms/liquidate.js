const { ethers } = require("hardhat");

const getLiquidationTerms = async (
  TFM,
  collateralManager,
  oracle,
  strategyId,
  compensation,
  alphaPenalisation,
  omegaPenalisation,
  postLiquidationAmplitude
) => {
  const oracleNonce = await TFM.oracleNonce();

  const strategy = await TFM.getStrategy(strategyId);

  const alphaInitialAllocation = await collateralManager.allocations(
    strategy.alpha,
    strategyId
  );
  const omegaInitialAllocation = await collateralManager.allocations(
    strategy.omega,
    strategyId
  );

  const hash = ethers.utils.solidityKeccak256(
    [
      "uint48",
      "address",
      "address",
      "address",
      "int256",
      "int256[2][]",
      "uint256",
      "int256",
      "uint256",
      "uint256",
      "int256",
      "uint256",
      "uint256",
    ],
    [
      strategy.expiry,
      strategy.bra,
      strategy.ket,
      strategy.basis,
      strategy.amplitude,
      strategy.phase,
      oracleNonce,
      compensation,
      alphaPenalisation,
      omegaPenalisation,
      postLiquidationAmplitude,
      alphaInitialAllocation,
      omegaInitialAllocation,
    ]
  );

  const oracleSignature = await oracle.signMessage(ethers.utils.arrayify(hash));

  const liquidationTerms = {
    oracleNonce,
    compensation,
    alphaPenalisation,
    omegaPenalisation,
    postLiquidationAmplitude,
  };

  return { oracleSignature, liquidationTerms };
};

module.exports = {
  getLiquidationTerms,
};
