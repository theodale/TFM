const { ethers } = require("hardhat");

const mintAndDeposit = async (depositor, deposit, basis, FundManager) => {
  await basis.mint(depositor.address, deposit);
  await basis.connect(depositor).approve(FundManager.address, deposit);
  await FundManager.connect(depositor).deposit(basis.address, deposit);
};

module.exports = {
  mintAndDeposit,
};
