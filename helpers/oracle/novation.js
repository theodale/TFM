const { ethers } = require("hardhat");

const getOracleNovationSignature = async (
  ActionLayer,
  oracle,
  strategyOneId,
  strategyTwoId,
  strategyOneResultingAlphaCollateralRequirement,
  strategyOneResultingOmegaCollateralRequirement,
  strategyTwoResultingAlphaCollateralRequirement,
  strategyTwoResultingOmegaCollateralRequirement,
  strategyOneResultingAmplitude,
  strategyTwoResultingAmplitude,
  fee
) => {
  const oracleNonce = await ActionLayer.oracleNonce();

  const strategyOne = await ActionLayer.getStrategy(strategyOneId);
  const strategyTwo = await ActionLayer.getStrategy(strategyTwoId);

  const hash = ethers.utils.solidityKeccak256(
    [
      "uint48",
      "address",
      "address",
      "address",
      "int256",
      "int256[2][]",
      "uint48",
      "address",
      "address",
      "address",
      "int256",
      "int256[2][]",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "int256",
      "int256",
      "uint256",
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
      oracleNonce,
      strategyOneResultingAlphaCollateralRequirement,
      strategyOneResultingOmegaCollateralRequirement,
      strategyTwoResultingAlphaCollateralRequirement,
      strategyTwoResultingOmegaCollateralRequirement,
      strategyOneResultingAmplitude,
      strategyTwoResultingAmplitude,
      fee,
    ]
  );

  const oracleSignature = await oracle.signMessage(ethers.utils.arrayify(hash));

  return oracleSignature;
};

module.exports = {
  getOracleNovationSignature,
};
