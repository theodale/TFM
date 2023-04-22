// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "../misc/Types.sol";

interface IAssetLayer {
    function executeSpearmint(
        uint256 _strategyId,
        address _alpha,
        address _omega,
        address _basis,
        int256 _premium,
        uint256 _alphaCollateralRequirement,
        uint256 _omegaCollateralRequirement,
        uint256 _alphaFee,
        uint256 _omegaFee
    ) external;

    function executePeppermint(ExecutePeppermintParameters calldata _parameters) external;

    function executeTransfer(ExecuteTransferParameters memory _parameters) external;

    event Deposit(address indexed user, address basis, uint256 amount);

    event Withdrawal(address indexed user, address basis, uint256 amount);

    event PeppermintDeposit(
        address indexed user,
        address indexed pepperminter,
        address basis,
        uint256 peppermintDepositId
    );

    event PeppermintWithdrawal(
        address indexed user,
        address indexed pepperminter,
        address basis,
        uint256 peppermintDepositId,
        uint256 amount
    );

    event WalletCreated(address user, address wallet);
}
