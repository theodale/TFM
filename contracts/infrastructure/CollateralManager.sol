// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "../interfaces/ICollateralManager.sol";
import "../interfaces/IWallet.sol";

import "../misc/Types.sol";

import "hardhat/console.sol";

contract CollateralManager is OwnableUpgradeable, ICollateralManager, UUPSUpgradeable {
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
    mapping(address => mapping(uint256 => uint256)) public allocations;

    // Records how many unallocated basis tokens a user has available to provide as collateral
    // Maps user => basis => amount
    mapping(address => mapping(address => uint256)) public reserves;

    // Users escrow tokens to be used by a specific pepperminter
    // Maps user => pepperminter => basis => deposit ID => deposit
    mapping(address => mapping(address => mapping(address => mapping(uint256 => PeppermintDeposit))))
        public peppermintDeposits;

    // Incrementing counters used to genenerate IDs that distinguish multiple deposits to the same pepperminter
    mapping(address => mapping(address => mapping(address => uint256))) private peppermintDepositCounters;

    /// *** MODIFIERS ***

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

        uint256 peppermintDepositId = peppermintDepositCounters[msg.sender][_pepperminter][_basis];

        peppermintDeposits[msg.sender][_pepperminter][_basis][peppermintDepositId] = PeppermintDeposit(
            _amount,
            _unlockTime
        );

        // emit PeppermintDeposit(msg.sender, _pepperminter, _basis, _amount);
    }

    function withdrawPeppermintDeposit(address _basis, uint256 _peppermintDepositId, address _pepperminter) external {
        PeppermintDeposit storage peppermintDeposit = peppermintDeposits[msg.sender][_pepperminter][_basis][
            _peppermintDepositId
        ];

        require(peppermintDeposit.unlockTime <= block.timestamp, "PEPPERMINT WITHDRAWAL: Deposit is still locked");

        uint256 amount = peppermintDeposit.amount;

        _transferFromWallet(msg.sender, _basis, msg.sender, amount);

        // User can still withdraw any funds that are subsequently added to the deposit with a deleted struct
        delete peppermintDeposits[msg.sender][_pepperminter][_basis][_peppermintDepositId];

        emit PeppermintWithdrawal(msg.sender, _pepperminter, _basis, _peppermintDepositId, amount);
    }

    // *** ALLOCATION TOP UP ***

    function topUp(uint256 _strategyId, uint256 amount) external {
        // asd
    }

    // *** ADMIN SETTERS ***

    function setTFM(address _tfm) external onlyOwner {
        tfm = _tfm;
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    // *** TFM COLLATERAL FUNCTIONALITY ***

    function executeSpearmint(ExecuteSpearmintParameters calldata _parameters) external tfmOnly {
        (uint256 alphaRemaining, uint256 omegaRemaining) = _processMint(
            _parameters,
            reserves[_parameters.alpha][_parameters.basis],
            reserves[_parameters.omega][_parameters.basis]
        );

        // Reduce deposits
        reserves[_parameters.alpha][_parameters.basis] = alphaRemaining;
        reserves[_parameters.omega][_parameters.basis] = omegaRemaining;
    }

    // Performs mint logic shared between spearmints and peppermints
    function _processMint(
        ExecuteSpearmintParameters calldata _parameters,
        uint256 availableAlpha,
        uint256 availableOmega
    ) internal tfmOnly returns (uint256 alphaRemaining, uint256 omegaRemaining) {
        // Set strategy allocations
        allocations[_parameters.alpha][_parameters.strategyId] = _parameters.alphaCollateralRequirement;
        allocations[_parameters.omega][_parameters.strategyId] = _parameters.omegaCollateralRequirement;

        // Cache wallets
        IWallet alphaWallet = wallets[_parameters.alpha];
        IWallet omegaWallet = wallets[_parameters.omega];

        uint256 totalAlphaRequirement = _parameters.alphaCollateralRequirement + _parameters.alphaFee;
        uint256 totalOmegaRequirement = _parameters.omegaCollateralRequirement + _parameters.omegaFee;

        uint256 absolutePremium;

        if (_parameters.premium > 0) {
            absolutePremium = uint256(_parameters.premium);

            availableOmega += absolutePremium;
            totalAlphaRequirement += absolutePremium;

            _transferFromWalletTwice(
                alphaWallet,
                _parameters.basis,
                address(omegaWallet),
                absolutePremium,
                treasury,
                _parameters.alphaFee
            );
            _transferFromWallet(omegaWallet, _parameters.basis, treasury, _parameters.omegaFee);
        } else {
            absolutePremium = uint256(-_parameters.premium);

            availableAlpha += absolutePremium;
            totalOmegaRequirement += absolutePremium;

            _transferFromWalletTwice(
                alphaWallet,
                _parameters.basis,
                address(alphaWallet),
                absolutePremium,
                treasury,
                _parameters.omegaFee
            );
            _transferFromWallet(alphaWallet, _parameters.basis, treasury, _parameters.alphaFee);
        }

        alphaRemaining = availableAlpha - totalAlphaRequirement;
        omegaRemaining = availableOmega - totalOmegaRequirement;
    }

    // // Pepperminters specify ID of each parties deposit
    // function peppermint(
    //     MintVariables calldata _parameters,
    //     address _pepperminter,
    //     uint256 _alphaDepositId,
    //     uint256 _omegaDepositId
    // ) external tfmOnly {
    //     PeppermintDeposit storage alphaPeppermintDeposit = peppermintDeposits[_parameters.alpha][_pepperminter][
    //         _parameters.basis
    //     ][_alphaDepositId];
    //     PeppermintDeposit storage omegaPeppermintDeposit = peppermintDeposits[_parameters.omega][_pepperminter][
    //         _parameters.basis
    //     ][_omegaDepositId];

    //     // Pepperminter cannot use unlocked deposits
    //     require(
    //         block.timestamp < alphaPeppermintDeposit.unlockTime,
    //         "COLLATERAL MANAGER: Alpha deposit is unlocked invalid"
    //     );
    //     require(block.timestamp < omegaPeppermintDeposit.unlockTime, "COLLATERAL MANAGER: Omega deposit is unlocked");

    //     (uint256 alphaRemaining, uint256 omegaRemaining) = _processMint(
    //         _parameters,
    //         alphaPeppermintDeposit.amount,
    //         omegaPeppermintDeposit.amount
    //     );

    //     // Reduce deposits
    //     alphaPeppermintDeposit.amount = alphaRemaining;
    //     omegaPeppermintDeposit.amount = omegaRemaining;
    // }

    // Premium transferred before collateral locked and fee taken
    function transfer(
        uint256 _strategyId,
        address _sender,
        address _recipient,
        address _basis,
        uint256 recipientCollateralRequirement,
        uint256 _senderFee,
        uint256 _recipientFee,
        int256 _premium
    ) external tfmOnly {
        // uint256 requirementRecipient = recipientCollateralRequirement + _recipientFee;
        // uint256 requirementSender = _senderFee;
        // uint256 availableRecipient = deposits[_recipient][_basis];
        // uint256 availableSender = deposits[_sender][_basis] + allocations[_sender][_strategyId];
        // // Use block to avoid stack depth issues
        // {
        //     IWallet senderWallet = wallets[_sender];
        //     IWallet recipientWallet = wallets[_recipient];
        //     uint256 absolutePremium;
        //     if (_premium > 0) {
        //         absolutePremium = uint256(_premium);
        //         _transferFromWalletTwice(
        //             senderWallet,
        //             _basis,
        //             address(recipientWallet),
        //             absolutePremium,
        //             treasury,
        //             _senderFee
        //         );
        //         _transferFromWallet(recipientWallet, _basis, treasury, _recipientFee);
        //         availableRecipient += absolutePremium;
        //         requirementSender += absolutePremium;
        //     } else {
        //         absolutePremium = uint256(-_premium);
        //         _transferFromWalletTwice(
        //             recipientWallet,
        //             _basis,
        //             address(senderWallet),
        //             absolutePremium,
        //             treasury,
        //             _recipientFee
        //         );
        //         _transferFromWallet(senderWallet, _basis, treasury, _senderFee);
        //         availableSender += absolutePremium;
        //         requirementRecipient += absolutePremium;
        //     }
        // }
        // // Update allocations
        // delete allocations[_sender][_strategyId];
        // allocations[_recipient][_strategyId] = recipientCollateralRequirement;
        // // Update deposits of transferring parties
        // deposits[_recipient][_basis] = availableRecipient - requirementRecipient;
        // deposits[_sender][_basis] = availableSender - requirementSender;
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
        //     allocations[_alphaOne][_strategyOneId] +
        //     allocations[_alphaOne][_strategyTwoId];
        // uint256 availableOmegaOne = deposits[_omegaOne][_basis] +
        //     allocations[_omegaOne][_strategyOneId] +
        //     allocations[_omegaOne][_strategyTwoId];
        // // Update deposits
        // deposits[_alphaOne][_basis] = availableAlphaOne - _resultingAlphaCollateralRequirement - _alphaOneFee;
        // deposits[_omegaOne][_basis] = availableOmegaOne - _resultingOmegaCollateralRequirement - _omegaOneFee;
        // // Set combined strategy allocations
        // allocations[_alphaOne][_strategyOneId] = _resultingAlphaCollateralRequirement;
        // allocations[_omegaOne][_strategyOneId] = _resultingOmegaCollateralRequirement;
        // // Delete redundant allocations
        // delete allocations[_alphaOne][_strategyTwoId];
        // delete allocations[_omegaOne][_strategyTwoId];
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
        //     deposits[_alpha][_basis] += allocations[_alpha][_strategyId] - absolutePayout;
        //     deposits[_omega][_basis] += absolutePayout + allocations[_omega][_strategyId];
        //     _transferFromWallet(_alpha, _basis, address(wallets[_omega]), absolutePayout);
        // } else {
        //     absolutePayout = uint256(-_payout);
        //     deposits[_alpha][_basis] += absolutePayout + allocations[_alpha][_strategyId];
        //     deposits[_omega][_basis] += allocations[_omega][_strategyId] - absolutePayout;
        //     _transferFromWallet(_omega, _basis, address(wallets[_alpha]), absolutePayout);
        // }
        // // Delete exercised strategy allocations
        // delete allocations[_alpha][_strategyId];
        // delete allocations[_omega][_strategyId];
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
        // allocations[_alpha][_strategyId] -= alphaReduction;
        // allocations[_omega][_strategyId] -= omegaReduction;
    }

    /// *** INTERNAL METHODS ***

    // Transfers ERC20 tokens from a user's wallet to a recipient address
    function _transferFromWallet(address _user, address _token, address _recipient, uint256 _amount) internal {
        wallets[_user].transferERC20(_token, _recipient, _amount);
    }

    // Transfers ERC20 tokens from a user's wallet to a recipient address
    function _transferFromWallet(IWallet _wallet, address _token, address _recipient, uint256 _amount) internal {
        _wallet.transferERC20(_token, _recipient, _amount);
    }

    function _transferFromWalletTwice(
        IWallet _walletOne,
        address _basis,
        address _recipientOne,
        uint256 _amountOne,
        address _recipientTwo,
        uint256 _amountTwo
    ) internal {
        _walletOne.transferERC20Twice(_basis, _recipientOne, _amountOne, _recipientTwo, _amountTwo);
    }

    // Grants owner upgrade authorization
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
