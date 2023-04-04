const { ethers } = require("hardhat");

const getCombinationTerms = async (
  TFM,
  oracle,
  strategyOneId,
  strategyTwoId,
  strategyOneAlphaFee,
  strategyOneOmegaFee,
  resultingAlphaCollateralRequirement,
  resultingOmegaCollateralRequirement,
  resultingPhase,
  resultingAmplitude
) => {
  const oracleNonce = await TFM.oracleNonce();

  const strategyOne = await TFM.getStrategy(strategyOneId);
  const strategyTwo = await TFM.getStrategy(strategyTwoId);

  const aligned = strategyOne.alpha == strategyTwo.alpha;

  const hash = ethers.utils.solidityKeccak256(
    [
      "uint256",
      "address",
      "address",
      "address",
      "int256",
      "int256[2][]",
      "uint256",
      "address",
      "address",
      "address",
      "int256",
      "int256[2][]",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "int256[2][]",
      "int256",
      "uint256",
      "bool",
    ],
    [
      strategyOne.expiry,
      strategyOne.bra,
      strategyOne.ket,
      strategyOne.basis,
      strategyOne.amplitude,
      strategyOne.phase,
      strategyTwo.expiry,
      strategyTwo.bra,
      strategyTwo.ket,
      strategyTwo.basis,
      strategyTwo.amplitude,
      strategyTwo.phase,
      strategyOneAlphaFee,
      strategyOneOmegaFee,
      resultingAlphaCollateralRequirement,
      resultingOmegaCollateralRequirement,
      resultingPhase,
      resultingAmplitude,
      oracleNonce,
      aligned,
    ]
  );

  const oracleSignature = await oracle.signMessage(ethers.utils.arrayify(hash));

  const combinationTerms = {
    strategyOneAlphaFee,
    strategyOneOmegaFee,
    resultingAlphaCollateralRequirement,
    resultingOmegaCollateralRequirement,
    resultingAmplitude,
    resultingPhase,
    oracleNonce,
    aligned,
  };

  return { oracleSignature, combinationTerms };
};

module.exports = {
  getCombinationTerms,
};
