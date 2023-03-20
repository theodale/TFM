const { ethers } = require("hardhat");

const generateSpearmintDataPackage = async (
  oracle,
  expiry,
  alphaCollateralRequirement,
  omegaCollateralRequirement,
  alphaFee,
  omegaFee,
  oracleNonce,
  bra,
  ket,
  basis,
  amplitude,
  phase
) => {
  const hash = ethers.utils.solidityKeccak256(
    [
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "address",
      "address",
      "address",
      "uint256",
      "int256[2][]",
    ],
    [
      expiry,
      alphaCollateralRequirement,
      omegaCollateralRequirement,
      alphaFee,
      omegaFee,
      oracleNonce,
      bra,
      ket,
      basis,
      amplitude,
      phase,
    ]
  );

  const trufinOracleSignature = await oracle.signMessage(
    ethers.utils.arrayify(hash)
  );

  const spearmintDataPackage = {
    expiry: expiry,
    alphaCollateralRequirement: alphaCollateralRequirement,
    omegaCollateralRequirement: omegaCollateralRequirement,
    alphaFee: alphaFee,
    omegaFee: omegaFee,
    oracleNonce: oracleNonce,
    bra: bra,
    ket: ket,
    basis: basis,
    amplitude: amplitude,
    phase: phase,
  };

  return { trufinOracleSignature, spearmintDataPackage };
};

module.exports = {
  generateSpearmintDataPackage,
};
