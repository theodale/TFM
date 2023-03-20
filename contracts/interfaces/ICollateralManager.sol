// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "../misc/Types.sol";

interface ICollateralManager {
    event Deposit(address indexed user, address indexed basis, uint256 amount);

    event Withdrawal(
        address indexed user,
        address indexed basis,
        uint256 amount
    );
}
