const { expect } = require("chai");

// This file contains functions that can be used to check conditions during tests

const checkCollateralAllocations = async (
  collateralManager,
  strategyId,
  users,
  allocations
) => {
  for (let i = 0; i < users.length; i++) {
    const allocatedCollateral = await collateralManager.allocations(
      users[i].address,
      strategyId
    );

    expect(allocatedCollateral).to.equal(allocations[i]);
  }
};

const checkUnallocatedCollateralBalances = async (
  collateralManager,
  basis,
  users,
  balances
) => {
  for (let i = 0; i < users.length; i++) {
    const unallocatedCollateral = await collateralManager.deposits(
      users[i].address,
      basis.address
    );

    expect(unallocatedCollateral).to.equal(balances[i]);
  }
};

const checkPoolBalanceChanges = async (
  CollateralManager,
  Basis,
  users,
  changes,
  transaction
) => {
  for (let i = 0; i < users.length; i++) {
    const personalPoolAddress = await CollateralManager.wallets(
      users[i].address
    );

    await expect(transaction).to.changeTokenBalance(
      Basis,
      personalPoolAddress,
      changes[i]
    );
  }
};

module.exports = {
  checkCollateralAllocations,
  checkUnallocatedCollateralBalances,
  checkPoolBalanceChanges,
};
