const { ethers } = require("hardhat");

export const SPEARMINT_TEST_PARAMETERS = {
  alphaDeposit: ethers.utils.parseEther("10"),
  omegaDeposit: ethers.utils.parseEther("10"),
  expiry: 1680000000,
  alphaCollateralRequirement: ethers.utils.parseEther("1"),
  omegaCollateralRequirement: ethers.utils.parseEther("1"),
  alphaFee: ethers.utils.parseEther("0.01"),
  omegaFee: ethers.utils.parseEther("0.01"),
  amplitude: ethers.utils.parseEther("10"),
  phase: [[ethers.utils.parseEther("1"), ethers.BigNumber.from("500000")]],
  premium: ethers.utils.parseEther("0.01"),
  transferable: true,
  payout: ethers.utils.parseEther("0.5"),
};
