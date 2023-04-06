// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "../misc/Types.sol";

interface ICollateralManager {
    function spearmint(
        uint256 _strategyId,
        address _alpha,
        address _omega,
        address _basis,
        uint256 _alphaCollateralRequirement,
        uint256 _omegaCollateralRequirement,
        uint256 _alphaFee,
        uint256 _omegaFee,
        int256 _premium
    ) external;

    function transfer(
        uint256 _strategyId,
        address _sender,
        address _recipient,
        address _basis,
        uint256 recipientCollateralRequirement,
        uint256 _senderFee,
        uint256 _recipientFee,
        int256 _premium
    ) external;

    function combine(
        uint256 _strategyOneId,
        uint256 _strategyTwoId,
        address _strategyOneAlpha,
        address _strategyOneOmega,
        address _basis,
        uint256 _resultingAlphaCollateralRequirement,
        uint256 _resultingOmegaCollateralRequirement,
        uint256 _strategyOneAlphaFee,
        uint256 _strategyOneOmegaFee
    ) external;

    function exercise(uint256 _strategyId, address _alpha, address _omega, address _basis, int256 _payout) external;

    function liquidate(
        uint256 _strategyId,
        address _alpha,
        address _omega,
        int256 _compensation,
        address _basis,
        uint256 _alphaFee,
        uint256 _omegaFee
    ) external;

    function allocatedCollateral(address _user, uint256 _strategyId) external returns (uint256);

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
