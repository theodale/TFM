const { ethers, upgrades } = require("hardhat");

const deploy = async (owner) => {
  // Deploy Utils library
  const UtilsFactory = await ethers.getContractFactory("Utils");
  const Utils = await UtilsFactory.deploy();

  // Logic contract factories
  const TFMFactory = await ethers.getContractFactory("TFM", {
    libraries: {
      Utils: Utils.address,
    },
  });
  const CollateralManagerFactory = await ethers.getContractFactory(
    "CollateralManager"
  );

  // Deploy proxies and implementation contracts
  const CollateralManager = await upgrades.deployProxy(
    CollateralManagerFactory,
    [owner.address, owner.address]
  );

  const TFM = await upgrades.deployProxy(
    TFMFactory,
    [CollateralManager.address, owner.address, owner.address, owner.address],
    {
      unsafeAllowLinkedLibraries: true,
      kind: "uups",
    }
  );

  await CollateralManager.setTFM(TFM.address);

  const MockERC20Factory = await ethers.getContractFactory("MockERC20");
  const MockERC20 = await MockERC20Factory.deploy();

  return {
    TFM,
    CollateralManager,
    MockERC20,
    Utils,
  };
};

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

const signSpearmintParameters = async (
  signer,
  trufinOracleSignature,
  alphaAddress,
  omegaAddress,
  premium,
  transferable,
  mintNonce
) => {
  const hash = ethers.utils.solidityKeccak256(
    ["bytes", "address", "address", "int256", "bool", "uint256", "uint8"],
    [
      trufinOracleSignature,
      alphaAddress,
      omegaAddress,
      premium,
      transferable,
      mintNonce,
      0,
    ]
  );

  const spearmintSignature = await signer.signMessage(
    ethers.utils.arrayify(hash)
  );

  const spearmintParameters = {
    trufinOracleSignature: trufinOracleSignature,
    alpha: alphaAddress,
    omega: omegaAddress,
    premium: premium,
    transferable: transferable,
    mintNonce: mintNonce,
  };

  return { spearmintSignature, spearmintParameters };
};

module.exports = {
  deploy,
  signSpearmintParameters,
  generateSpearmintDataPackage,
};
