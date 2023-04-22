// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "../misc/Types.sol";

interface IActionLayer {
    event Spearmint(uint256 strategyId);

    event Peppermint(uint256 strategyId);

    event Transfer(uint256 strategyId);

    event Combination(uint256 strategyOneId, uint256 strategyTwoId);

    event Novation(uint256 strategyOneId, uint256 strategyTwoId);

    event Withdraw(uint256 strategyId);

    event Exercise(uint256 strategyId);

    event Liquidation(uint256 strategyId);

    event OracleNonceUpdated(uint256 oracleNonce);

    event Deposit(address indexed user, address indexed basis, uint256 amount);

    event Withdrawal(address indexed user, address indexed basis, uint256 amount);

    event PeppermintWithdrawal(
        address indexed user,
        address indexed pepperminter,
        address indexed basis,
        uint256 peppermintDepositId,
        uint256 amount
    );

    event WalletCreated(address _user, address _wallet);
}
