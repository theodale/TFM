const { ethers } = require("hardhat");

// These objects contain the default parameter values used in the tests

const STRATEGY = {
  expiry: 1680000000,
  amplitude: ethers.utils.parseEther("10"),
  phase: [[ethers.utils.parseEther("1"), ethers.BigNumber.from("500000")]],
  transferable: true,
};

const SPEARMINT = {
  alphaCollateralRequirement: ethers.utils.parseEther("1"),
  omegaCollateralRequirement: ethers.utils.parseEther("1"),
  alphaFee: ethers.utils.parseEther("0.01"),
  omegaFee: ethers.utils.parseEther("0.01"),
  premium: ethers.utils.parseEther("0.1"),
};

const TRANSFER = {
  premium: ethers.utils.parseEther("0.1"),
  senderFee: ethers.utils.parseEther("0.01"),
  recipientFee: ethers.utils.parseEther("0.01"),
  recipientCollateralRequirement: ethers.utils.parseEther("1"),
};

const EXERCISE = {
  payout: ethers.utils.parseEther("0.5"),
};

const LIQUIDATION = {
  compensation: ethers.utils.parseEther("0.1"),
  alphaFee: ethers.utils.parseEther("0.01"),
  omegaFee: ethers.utils.parseEther("0.01"),
  postLiquidationAmplitude: ethers.utils.parseEther("5"),
};

module.exports = {
  STRATEGY,
  SPEARMINT,
  TRANSFER,
  EXERCISE,
  LIQUIDATION,
};
