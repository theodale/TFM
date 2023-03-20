// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

interface IPersonalPool {
    function transferERC20(
        address _to,
        address _basisAddress,
        uint256 _amount
    ) external;
}
