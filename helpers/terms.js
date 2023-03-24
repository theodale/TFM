const { ethers } = require("hardhat");

const generateSpearmintTerms = async (
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
      bra.address,
      ket.address,
      basis.address,
      amplitude,
      phase,
    ]
  );

  const trufinOracleSignature = await oracle.signMessage(
    ethers.utils.arrayify(hash)
  );

  const spearMintTerms = {
    expiry: expiry,
    alphaCollateralRequirement: alphaCollateralRequirement,
    omegaCollateralRequirement: omegaCollateralRequirement,
    alphaFee: alphaFee,
    omegaFee: omegaFee,
    oracleNonce: oracleNonce,
    bra: bra.address,
    ket: ket.address,
    basis: basis.address,
    amplitude: amplitude,
    phase: phase,
  };

  return { trufinOracleSignature, spearMintTerms };
};

module.exports = {
  generateSpearmintTerms,
};
