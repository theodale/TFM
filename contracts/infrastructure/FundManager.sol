// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "../interfaces/IFundManager.sol";
import "../interfaces/IWallet.sol";

import "../misc/Types.sol";

import "hardhat/console.sol";

contract FundManager is IFundManager, OwnableUpgradeable, UUPSUpgradeable {
    // *** LIBRARIES ***

    using SafeERC20 for IERC20;

    // *** STATE VARIABLES ***

    // Fee recipient
    address treasury;

    // Address of the TFM that controls this manager
    address tfm;

    // Implementation for wallet proxies
    address walletImplementation;

    // Stores each user's wallet
    mapping(address => IWallet) public wallets;

    // Records how much collateral a user has allocated to a strategy
    // Maps user => strategy ID => amount
    mapping(address => mapping(uint256 => CollateralBalance)) public collateralBalances;

    // Records how many unallocated basis tokens a user has available to provide as collateral
    // Maps user => basis => amount
    mapping(address => mapping(address => uint256)) public reserves;

    // Escrowed tokens to be used by a specific pepperminter
    // Maps user => pepperminter => basis => deposit ID => deposit
    mapping(address => mapping(address => mapping(address => mapping(uint256 => LockedDeposit)))) public lockedDeposits;

    // Incrementing counters used to genenerate IDs that distinguish multiple locked deposits to the same pepperminter
    // Maps user => pepperminter => basis => next deposit ID
    mapping(address => mapping(address => mapping(address => uint256))) public lockedDepositCounters;

    // *** MODIFIERS ***

    modifier tfmOnly() {
        require(msg.sender == tfm, "COLLATERAL MANAGER: TFM only");
        _;
    }

    // *** INITIALIZER ***

    function initialize(address _treasury, address _owner, address _walletImplementation) external initializer {
        // Initialize inherited state
        __Ownable_init();
        transferOwnership(_owner);
        __UUPSUpgradeable_init();

        // Initialize contract state
        treasury = _treasury;
        walletImplementation = _walletImplementation;
    }

    // *** WALLET CREATION ***

    // Deploys a new wallet for the caller if they do not have one
    function createWallet() external {
        require(address(wallets[msg.sender]) == address(0), "COLLATERAL MANAGER: Caller has wallet already");

        // Deploy proxy & initialize
        IWallet wallet = IWallet(Clones.clone(walletImplementation));
        wallet.initialize();

        // Register wallet
        wallets[msg.sender] = wallet;

        emit WalletCreated(msg.sender, address(wallet));
    }

    // *** WITHDRAWALS & DEPOSITS ***

    // Deposit basis tokens into unallocated collateral balance
    function deposit(address _basis, uint256 _amount) external {
        address walletAddress = address(wallets[msg.sender]);

        IERC20(_basis).safeTransferFrom(msg.sender, walletAddress, _amount);

        reserves[msg.sender][_basis] += _amount;

        emit Deposit(msg.sender, _basis, _amount);
    }

    function depositNativeToken() external {}

    // Withdraw unallocated basis tokens
    function withdraw(address _basis, uint256 amount) external {
        reserves[msg.sender][_basis] -= amount;

        _transferFromWallet(msg.sender, _basis, msg.sender, amount);

        emit Withdrawal(msg.sender, _basis, amount);
    }

    function depositForPeppermint(
        address _pepperminter,
        address _basis,
        uint256 _amount,
        uint256 _unlockTime
    ) external {
        address walletAddress = address(wallets[msg.sender]);

        IERC20(_basis).safeTransferFrom(msg.sender, walletAddress, _amount);

        uint256 peppermintDepositId = lockedDepositCounters[msg.sender][_pepperminter][_basis];

        lockedDeposits[msg.sender][_pepperminter][_basis][peppermintDepositId] = LockedDeposit(_amount, _unlockTime);

        lockedDepositCounters[msg.sender][_pepperminter][_basis]++;

        emit PeppermintDeposit(msg.sender, _pepperminter, _basis, _amount);
    }

    function withdrawPeppermintDeposit(address _basis, uint256 _peppermintDepositId, address _pepperminter) external {
        LockedDeposit storage peppermintDeposit = lockedDeposits[msg.sender][_pepperminter][_basis][
            _peppermintDepositId
        ];

        require(peppermintDeposit.unlockTime <= block.timestamp, "PEPPERMINT WITHDRAWAL: Deposit is still locked");

        uint256 amount = peppermintDeposit.amount;

        _transferFromWallet(msg.sender, _basis, msg.sender, amount);

        // User can still withdraw any funds that are subsequently added to the deposit with a deleted struct
        delete lockedDeposits[msg.sender][_pepperminter][_basis][_peppermintDepositId];

        emit PeppermintWithdrawal(msg.sender, _pepperminter, _basis, _peppermintDepositId, amount);
    }

    // *** ALLOCATION MANAGEMENT ***

    function topUp(uint256 _strategyId, uint256 _amount) external {
        // asd
    }

    // *** ADMIN SETTERS ***

    function setTFM(address _tfm) external onlyOwner {
        tfm = _tfm;
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    // *** TFM COLLATERAL MANAGEMENT METHODS ***

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
    ) external tfmOnly {
        SharedMintLogicParameters memory parameters = SharedMintLogicParameters(
            _strategyId,
            _alpha,
            _omega,
            _basis,
            _premium,
            _alphaCollateralRequirement,
            _omegaCollateralRequirement,
            reserves[_alpha][_basis],
            reserves[_omega][_basis],
            _alphaFee,
            _omegaFee
        );

        (uint256 alphaRemaining, uint256 omegaRemaining) = _sharedMintLogic(parameters);

        // Reduce deposits
        reserves[_alpha][_basis] = alphaRemaining;
        reserves[_omega][_basis] = omegaRemaining;
    }

    // Pepperminters specify ID of each parties deposit
    function executePeppermint(ExecutePeppermintParameters calldata _parameters) external tfmOnly {
        LockedDeposit storage alphaDeposit = lockedDeposits[_parameters.alpha][_parameters.pepperminter][
            _parameters.basis
        ][_parameters.alphaDepositId];
        LockedDeposit storage omegaDeposit = lockedDeposits[_parameters.omega][_parameters.pepperminter][
            _parameters.basis
        ][_parameters.omegaDepositId];

        // Pepperminter cannot use unlocked deposits
        require(block.timestamp < alphaDeposit.unlockTime, "COLLATERAL MANAGER: Alpha deposit is unlocked");
        require(block.timestamp < omegaDeposit.unlockTime, "COLLATERAL MANAGER: Omega deposit is unlocked");

        SharedMintLogicParameters memory parameters = SharedMintLogicParameters(
            _parameters.strategyId,
            _parameters.alpha,
            _parameters.omega,
            _parameters.basis,
            _parameters.premium,
            _parameters.alphaCollateralRequirement,
            _parameters.omegaCollateralRequirement,
            alphaDeposit.amount,
            omegaDeposit.amount,
            _parameters.alphaFee,
            _parameters.omegaFee
        );

        (uint256 alphaRemaining, uint256 omegaRemaining) = _sharedMintLogic(parameters);

        // Reduce deposits
        alphaDeposit.amount = alphaRemaining;
        omegaDeposit.amount = omegaRemaining;
    }

    // 443542

    // Ensure correct collateral and security flow when transferring to self
    // Premium transferred before collateral locked and fee taken
    function executeTransfer(ExecuteTransferParameters calldata _parameters) external tfmOnly {
        uint256 requirementRecipient = _parameters.recipientCollateralRequirement + _parameters.recipientFee;
        uint256 requirementSender = _parameters.senderFee;

        uint256 availableRecipient = reserves[_parameters.recipient][_parameters.basis];
        uint256 availableSender = reserves[_parameters.sender][_parameters.basis] +
            (
                _parameters.alphaTransfer
                    ? collateralBalances[_parameters.sender][_parameters.strategyId].alphaBalance
                    : collateralBalances[_parameters.sender][_parameters.strategyId].omegaBalance
            );

        {
            uint256 absolutePremium;

            // NEED TO CACHE one wallet type each time

            if (_parameters.premium > 0) {
                absolutePremium = uint256(_parameters.premium);

                _transferFromWalletTwice(
                    _parameters.basis,
                    _parameters.sender,
                    address(wallets[_parameters.recipient]),
                    absolutePremium,
                    treasury,
                    _parameters.senderFee
                );

                _transferFromWallet(_parameters.basis, _parameters.recipient, treasury, _parameters.recipientFee);

                availableRecipient += absolutePremium;
                requirementSender += absolutePremium;
            } else {
                absolutePremium = uint256(-_parameters.premium);

                _transferFromWalletTwice(
                    _parameters.basis,
                    _parameters.recipient,
                    address(wallets[_parameters.sender]),
                    absolutePremium,
                    treasury,
                    _parameters.recipientFee
                );

                _transferFromWallet(_parameters.basis, _parameters.sender, treasury, _parameters.senderFee);

                availableSender += absolutePremium;
                requirementRecipient += absolutePremium;
            }
        }

        // Update collateral
        if (_parameters.alphaTransfer) {
            collateralBalances[_parameters.sender][_parameters.strategyId].alphaBalance = 0;
            collateralBalances[_parameters.recipient][_parameters.strategyId].alphaBalance = _parameters
                .recipientCollateralRequirement;
        } else {
            collateralBalances[_parameters.sender][_parameters.strategyId].omegaBalance = 0;
            collateralBalances[_parameters.recipient][_parameters.strategyId].omegaBalance = _parameters
                .recipientCollateralRequirement;
        }

        // Update transferring parties' reserves
        reserves[_parameters.recipient][_parameters.basis] = availableRecipient - requirementRecipient;
        reserves[_parameters.sender][_parameters.basis] = availableSender - requirementSender;
    }

    // *** INTERNAL METHODS ***

    // Transfers ERC20 tokens from a user's wallet to a recipient address
    function _transferFromWallet(address _token, address _user, address _recipient, uint256 _amount) internal {
        wallets[_user].transferERC20(_token, _recipient, _amount);
    }

    function _transferFromWalletTwice(
        address _token,
        address _sender,
        address _recipientOne,
        uint256 _amountOne,
        address _recipientTwo,
        uint256 _amountTwo
    ) internal {
        wallets[_sender].transferERC20Twice(_token, _recipientOne, _amountOne, _recipientTwo, _amountTwo);
    }

    // Performs mint logic shared between spearmints and peppermints
    // Reserve/Peppermint deposit updates are carried out in the calling function ()
    function _sharedMintLogic(
        SharedMintLogicParameters memory _parameters
    ) internal returns (uint256 alphaRemaining, uint256 omegaRemaining) {
        // Set strategy collaterals
        collateralBalances[_parameters.alpha][_parameters.strategyId].alphaBalance = _parameters
            .alphaCollateralRequirement;
        collateralBalances[_parameters.omega][_parameters.strategyId].omegaBalance = _parameters
            .omegaCollateralRequirement;

        uint256 absolutePremium;

        // Transfer fees and premium
        if (_parameters.premium > 0) {
            absolutePremium = uint256(_parameters.premium);

            alphaRemaining =
                _parameters.alphaAvailable -
                absolutePremium -
                _parameters.alphaCollateralRequirement -
                _parameters.alphaFee;
            omegaRemaining =
                _parameters.omegaAvailable +
                absolutePremium -
                _parameters.omegaCollateralRequirement -
                _parameters.omegaFee;

            _transferFromWalletTwice(
                _parameters.basis,
                _parameters.alpha,
                address(wallets[_parameters.omega]),
                absolutePremium,
                treasury,
                _parameters.alphaFee
            );

            _transferFromWallet(_parameters.basis, _parameters.omega, treasury, _parameters.omegaFee);
        } else {
            absolutePremium = uint256(-_parameters.premium);

            alphaRemaining =
                _parameters.alphaAvailable +
                absolutePremium -
                _parameters.alphaCollateralRequirement -
                _parameters.alphaFee;
            omegaRemaining =
                _parameters.omegaAvailable -
                absolutePremium -
                _parameters.omegaCollateralRequirement -
                _parameters.omegaFee;

            _transferFromWalletTwice(
                _parameters.alpha,
                _parameters.basis,
                address(wallets[_parameters.omega]),
                absolutePremium,
                treasury,
                _parameters.omegaFee
            );

            _transferFromWallet(_parameters.alpha, _parameters.basis, treasury, _parameters.alphaFee);
        }

        return (alphaRemaining, omegaRemaining);
    }

    // Issue if alpha == omega
    function combine(
        uint256 _strategyOneId,
        uint256 _strategyTwoId,
        address _alphaOne,
        address _omegaOne,
        address _basis,
        uint256 _resultingAlphaCollateralRequirement,
        uint256 _resultingOmegaCollateralRequirement,
        uint256 _alphaOneFee,
        uint256 _omegaOneFee
    ) external tfmOnly {
        // // Get each combiner's available collateral for their combined strategy position
        // uint256 availableAlphaOne = deposits[_alphaOne][_basis] +
        //     collaterals[_alphaOne][_strategyOneId] +
        //     collaterals[_alphaOne][_strategyTwoId];
        // uint256 availableOmegaOne = deposits[_omegaOne][_basis] +
        //     collaterals[_omegaOne][_strategyOneId] +
        //     collaterals[_omegaOne][_strategyTwoId];
        // // Update deposits
        // deposits[_alphaOne][_basis] = availableAlphaOne - _resultingAlphaCollateralRequirement - _alphaOneFee;
        // deposits[_omegaOne][_basis] = availableOmegaOne - _resultingOmegaCollateralRequirement - _omegaOneFee;
        // // Set combined strategy collaterals
        // collaterals[_alphaOne][_strategyOneId] = _resultingAlphaCollateralRequirement;
        // collaterals[_omegaOne][_strategyOneId] = _resultingOmegaCollateralRequirement;
        // // Delete redundant collaterals
        // delete collaterals[_alphaOne][_strategyTwoId];
        // delete collaterals[_omegaOne][_strategyTwoId];
        // // Transfer fees
        // _transferFromWallet(_alphaOne, _basis, treasury, _alphaOneFee);
        // _transferFromWallet(_omegaOne, _basis, treasury, _omegaOneFee);
    }

    function novate() external tfmOnly {}

    // Potential DoS => allocation is less than payout => liquidation is required
    function exercise(
        uint256 _strategyId,
        address _alpha,
        address _omega,
        address _basis,
        int256 _payout
    ) external tfmOnly {
        // uint256 absolutePayout;
        // if (_payout > 0) {
        //     absolutePayout = uint256(_payout);
        //     deposits[_alpha][_basis] += collaterals[_alpha][_strategyId] - absolutePayout;
        //     deposits[_omega][_basis] += absolutePayout + collaterals[_omega][_strategyId];
        //     _transferFromWallet(_alpha, _basis, address(wallets[_omega]), absolutePayout);
        // } else {
        //     absolutePayout = uint256(-_payout);
        //     deposits[_alpha][_basis] += absolutePayout + collaterals[_alpha][_strategyId];
        //     deposits[_omega][_basis] += collaterals[_omega][_strategyId] - absolutePayout;
        //     _transferFromWallet(_omega, _basis, address(wallets[_alpha]), absolutePayout);
        // }
        // // Delete exercised strategy collaterals
        // delete collaterals[_alpha][_strategyId];
        // delete collaterals[_omega][_strategyId];
    }

    function liquidate(
        uint256 _strategyId,
        address _alpha,
        address _omega,
        int256 _compensation,
        address _basis,
        uint256 _alphaPenalisation,
        uint256 _omegaPenalisation
    ) external tfmOnly {
        // // Cache wallets on stack
        // IWallet alphaWallet = wallets[_alpha];
        // IWallet omegaWallet = wallets[_omega];
        // // Cache to avoid multiple storage writes
        // uint256 alphaReduction;
        // uint256 omegaReduction;
        // uint256 absoluteCompensation;
        // // Process any compensation
        // if (_compensation > 0) {
        //     absoluteCompensation = uint256(_compensation);
        //     deposits[_omega][_basis] += absoluteCompensation;
        //     alphaReduction = absoluteCompensation;
        //     _transferFromWallet(alphaWallet, _basis, address(omegaWallet), absoluteCompensation);
        // } else if (_compensation < 0) {
        //     absoluteCompensation = uint256(-_compensation);
        //     deposits[_alpha][_basis] += absoluteCompensation;
        //     omegaReduction = absoluteCompensation;
        //     _transferFromWallet(omegaWallet, _basis, address(alphaWallet), absoluteCompensation);
        // }
        // // Transfer protocol fees
        // if (_alphaPenalisation > 0) {
        //     alphaReduction += _alphaPenalisation;
        //     _transferFromWallet(alphaWallet, _basis, treasury, _alphaPenalisation);
        // }
        // if (_omegaPenalisation > 0) {
        //     omegaReduction += _omegaPenalisation;
        //     _transferFromWallet(omegaWallet, _basis, treasury, _omegaPenalisation);
        // }
        // collaterals[_alpha][_strategyId] -= alphaReduction;
        // collaterals[_omega][_strategyId] -= omegaReduction;
    }

    /// *** INTERNAL METHODS ***

    // Grants owner upgrade authorization
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
