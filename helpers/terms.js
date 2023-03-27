const { ethers } = require("hardhat");

// This module contains functions that sign terms for TFM actions
// These functions return:
// - a signature made by an input oracle for the specified terms
// - a terms object that can be passed as the relevant terms struct to the TFM action function

const getSpearmintTerms = async (
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
    expiry,
    alphaCollateralRequirement,
    omegaCollateralRequirement,
    alphaFee,
    omegaFee,
    oracleNonce,
    bra: bra.address,
    ket: ket.address,
    basis: basis.address,
    amplitude,
    phase,
  };

  return { oracleSignature, spearmintTerms };
};

const getTransferTerms = async (
  TFM,
  strategyId,
  oracle,
  recipientCollateralRequirement,
  senderFee,
  recipientFee,
  alphaTransfer
) => {
  const oracleNonce = await TFM.oracleNonce();

  const strategy = await TFM.getStrategy(strategyId);

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
      "bool",
      "uint256",
    ],
    [
      strategy.expiry,
      strategy.bra,
      strategy.ket,
      strategy.basis,
      strategy.amplitude,
      strategy.phase,
      senderFee,
      recipientFee,
      recipientCollateralRequirement,
      alphaTransfer,
      oracleNonce,
    ]
  );

  const oracleSignature = await oracle.signMessage(ethers.utils.arrayify(hash));

  const transferTerms = {
    recipientCollateralRequirement,
    oracleNonce,
    senderFee,
    recipientFee,
    alphaTransfer,
  };

  return { oracleSignature, transferTerms };
};

module.exports = {
  getSpearmintTerms,
  getTransferTerms,
};
