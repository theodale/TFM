const { ethers } = require("hardhat");

// These exported objects contain sets of parameter values used for testing

const STRATEGY = {
  expiry: 1680000000,
  amplitude: ethers.utils.parseEther("10"),
  phase: [[ethers.utils.parseEther("1"), ethers.BigNumber.from("500000")]],
  transferable: true,
};

const MINT = {
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

const COMBINATION = {
  strategyOneAlphaFee: ethers.utils.parseEther("0.01"),
  strategyOneOmegaFee: ethers.utils.parseEther("0.01"),
  resultingAlphaCollateralRequirement: ethers.utils.parseEther("1"),
  resultingOmegaCollateralRequirement: ethers.utils.parseEther("1"),
  resultingPhase: [
    [ethers.utils.parseEther("1"), ethers.BigNumber.from("500000")],
  ],
  resultingAmplitude: ethers.utils.parseEther("10"),
};

const NOVATION = {
  strategyOneResultingAlphaCollateralRequirement:
    ethers.utils.parseEther("0.1"),
  strategyOneResultingOmegaCollateralRequirement:
    ethers.utils.parseEther("0.2"),
  strategyTwoResultingAlphaCollateralRequirement:
    ethers.utils.parseEther("0.3"),
  strategyTwoResultingOmegaCollateralRequirement:
    ethers.utils.parseEther("0.4"),
  strategyOneResultingAmplitude: ethers.utils.parseEther("5"),
  strategyTwoResultingAmplitude: ethers.utils.parseEther("4"),
  fee: ethers.utils.parseEther("0.01"),
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
  MINT,
  TRANSFER,
  COMBINATION,
  NOVATION,
  EXERCISE,
  LIQUIDATION,
};
