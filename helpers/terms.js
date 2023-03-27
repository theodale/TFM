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

  const oracleSignature = await oracle.signMessage(ethers.utils.arrayify(hash));

  const spearmintTerms = {
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

  return { oracleSignature, spearmintTerms };
};

const generateExerciseTerms = async (
  TFM,
  oracle,
  payout,
  alphaFee,
  omegaFee,
  expiry,
  bra,
  ket,
  basis,
  amplitude,
  phase
) => {
  const oracleNonce = await TFM.oracleNonce();

  const hash = ethers.utils.solidityKeccak256(
    [
      "uint256",
      "address",
      "address",
      "address",
      "uint256",
      "int256[2][]",
      "uint256",
      "uint256",
      "uint256",
      "int256",
    ],
    [
      expiry,
      bra.address,
      ket.address,
      basis.address,
      amplitude,
      phase,
      oracleNonce,
      alphaFee,
      omegaFee,
      payout,
    ]
  );

  const oracleSignature = await oracle.signMessage(ethers.utils.arrayify(hash));

  const exerciseTerms = {
    payout: payout,
    oracleNonce: oracleNonce,
    alphaFee,
    omegaFee,
  };

  return { oracleSignature, exerciseTerms };
};

const generateCombinationTerms = async (
  TFM,
  oracle,
  payout,
  alphaFee,
  omegaFee,
  expiry,
  bra,
  ket,
  basis,
  amplitude,
  phase
) => {
  const oracleNonce = await TFM.oracleNonce();

  const hash = ethers.utils.solidityKeccak256(
    [
      "uint256",
      "address",
      "address",
      "address",
      "uint256",
      "int256[2][]",
      "uint256",
      "uint256",
      "uint256",
      "int256",
    ],
    [
      expiry,
      bra.address,
      ket.address,
      basis.address,
      amplitude,
      phase,
      oracleNonce,
      alphaFee,
      omegaFee,
      payout,
    ]
  );

  const oracleSignature = await oracle.signMessage(ethers.utils.arrayify(hash));

  const exerciseTerms = {
    payout,
    oracleNonce,
    alphaFee,
    omegaFee,
  };

  return { oracleSignature, exerciseTerms };
};

module.exports = {
  generateSpearmintTerms,
  generateExerciseTerms,
};
