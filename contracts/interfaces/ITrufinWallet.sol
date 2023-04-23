// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

interface ITrufinWallet {
    function initialize() external;

    function transferERC20(address _basis, address _recipient, uint256 _amount) external;

    function transferERC20Twice(
        address _basis,
        address _recipientOne,
        uint256 _amountOne,
        address _recipientTwo,
        uint256 _amountTwo
    ) external;
}
