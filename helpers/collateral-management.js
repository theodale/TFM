const { ethers } = require("hardhat");

const mintAndDeposit = async (collateralManager, basis, user, amount) => {
  await basis.mint(user.address, amount);
  await basis.connect(user).approve(collateralManager.address, amount);
  await collateralManager.connect(user).deposit(basis.address, amount);
};

module.exports = {
  mintAndDeposit,
};
