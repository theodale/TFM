// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

interface IPersonalPool {
    /**
        @notice Function to approve the transfer of funds for msg.sender (the Collateral Manager).
        @param _basisAddress address of ERC20 token to be approved
        @param _amount of ERC20 token to approve
    */
    //slither-disable-next-line erc20-interface
    function approve(address _basisAddress, uint256 _amount) external;

    /**
        @notice Function to withdraw Native coin from PersonalPool
        @param _to address which will be used as a recipient
        @param _amount of native coin to withdraw
    */
    function transferNative(address payable _to, uint256 _amount) external;

    function transferERC20(
        address _to,
        address _basisAddress,
        uint256 _amount
    ) external;
}
