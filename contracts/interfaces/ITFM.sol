// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "../misc/Types.sol";

interface ITFM {
    event Initialization();

    event Spearmint(uint256 strategyId);

    event Transfer(uint256 strategyId);

    event Combination(uint256 strategyOneId, uint256 strategyTwoId);

    event Withdraw(uint256 strategyId);

    event Exercise(uint256 strategyId);

    event OracleNonceUpdated(uint256 oracleNonce);
}
