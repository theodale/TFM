// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

interface IWallet {
    function initialize() external;

    function transferERC20(address _basis, address _recipient, uint256 _amount) external;
}
