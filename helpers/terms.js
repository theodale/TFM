const { ethers } = require("hardhat");

// This module contains functions that sign terms for TFM methods
// These functions return:
// - a signature made by an input oracle for the specified terms
// - a terms object that can be passed as the relevant terms struct to the TFM method in question

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

const getExerciseTerms = async (
  TFM,
  oracle,
  strategyId,
  payout,
  alphaFee,
  omegaFee
) => {
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
      "uint256",
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

// const getLiquidationTerms = async (
//   TFM,
//   collateralManager,
//   oracle,
//   strategyId,
//   payout,
//   alphaFee,
//   omegaFee
// ) => {
//   const oracleNonce = await TFM.oracleNonce();

//   const strategy = await TFM.getStrategy(strategyId);

//   const alphaInitialAllocation = collateralManager.allocatedCollateral(
//     strategyId,
//     strategy.alpha
//   );
//   const omegaInitialAllocation = collateralManager.allocatedCollateral(
//     strategyId,
//     strategy.omega
//   );

//   const hash = ethers.utils.solidityKeccak256(
//     [
//       "uint256",
//       "address",
//       "address",
//       "address",
//       "int256",
//       "int256[2][]",
//       "uint256",
//       "uint256",
//       "uint256",
//       "int256",
//     ],
//     [
//       strategy.expiry,
//       strategy.bra,
//       strategy.ket,
//       strategy.basis,
//       strategy.amplitude,
//       strategy.phase,
//       senderFee,
//       oracleNonce,

//       payout,
//     ]
//   );

//   // _strategy.expiry,
//   // _strategy.bra,
//   // _strategy.ket,
//   // _strategy.basis,
//   // _strategy.amplitude,
//   // _strategy.phase,
//   // _terms.oracleNonce,
//   // _terms.alphaFee,
//   // _terms.omegaFee,
//   // _terms.payout

//   const oracleSignature = await oracle.signMessage(ethers.utils.arrayify(hash));

//   const exerciseTerms = {
//     payout,
//     oracleNonce,
//     alphaFee,
//     omegaFee,
//   };

//   return { oracleSignature, exerciseTerms };
// };

module.exports = {
  getSpearmintTerms,
  getTransferTerms,
  getExerciseTerms,
};
