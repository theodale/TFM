const { ethers } = require("hardhat");

const STRATEGY_ONE = {
  expiry: 1680000000,
  amplitude: ethers.utils.parseEther("10"),
  phase: [[ethers.utils.parseEther("1"), ethers.BigNumber.from("500000")]],
  transferable: true,
  payout: ethers.utils.parseEther("0.5"),
};

const SPEARMINT_ONE = {
  alphaCollateralRequirement: ethers.utils.parseEther("1"),
  omegaCollateralRequirement: ethers.utils.parseEther("1"),
  alphaFee: ethers.utils.parseEther("0.01"),
  omegaFee: ethers.utils.parseEther("0.01"),
  premium: ethers.utils.parseEther("0.1"),
};

const EXERCISE_ONE = {
  payout: ethers.utils.parseEther("0.5"),
  alphaFee: ethers.utils.parseEther("0.01"),
  omegaFee: ethers.utils.parseEther("0.01"),
};

const LIQUDATION_ONE = {
  compensation: ethers.utils.parseEther("0.1"),
  alphaFee: ethers.utils.parseEther("0.01"),
  omegaFee: ethers.utils.parseEther("0.01"),
  postLiquidationAmplitude: ethers.utils.parseEther("5"),
};

module.exports = {
  STRATEGY_ONE,
  SPEARMINT_ONE,
  EXERCISE_ONE,
  LIQUDATION_ONE,
};
