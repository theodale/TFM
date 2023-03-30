const { ethers } = require("hardhat");

const getSpearmintTerms = async (
  TFM,
  oracle,
  expiry,
  alphaCollateralRequirement,
  omegaCollateralRequirement,
  alphaFee,
  omegaFee,
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

module.exports = {
  getSpearmintTerms,
};
