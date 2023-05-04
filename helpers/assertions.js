const { expect } = require("chai");

// This file contains functions that can be used to check conditions during tests

const checkAllocations = async (
  FundManager,
  strategyId,
  users,
  allocations
) => {
  for (let i = 0; i < users.length; i++) {
    const collateralBalance = await FundManager.collaterals(
      users[i].address,
      strategyId
    );

    expect(collateralBalance.alphaBalance).to.equal(
      allocations[i].alphaBalance
    );
    expect(collateralBalance.omegaBalance).to.equal(
      allocations[i].omegaBalance
    );
  }
};

const checkReserves = async (FundManager, basis, users, balances) => {
  for (let i = 0; i < users.length; i++) {
    const unallocatedCollateral = await FundManager.reserves(
      users[i].address,
      basis.address
    );

    expect(unallocatedCollateral).to.equal(balances[i]);
  }
};

const checkWalletBalanceChanges = async (
  FundManager,
  Basis,
  users,
  changes,
  transaction
) => {
  for (let i = 0; i < users.length; i++) {
    const walletAddress = await FundManager.wallets(users[i].address);

    await expect(transaction).to.changeTokenBalance(
      Basis,
      walletAddress,
      changes[i]
    );
  }
};

module.exports = {
  checkAllocations,
  checkReserves,
  checkWalletBalanceChanges,
};
