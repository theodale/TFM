// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "../interfaces/IAssetLayer.sol";
import "../interfaces/ITrufinWallet.sol";

import "../misc/Types.sol";

import "hardhat/console.sol";

/// @title TFM Asset Layer
/// @author Field Labs
contract AssetLayer is IAssetLayer, OwnableUpgradeable, UUPSUpgradeable {
    // *** LIBRARIES ***

    using SafeERC20 for IERC20;

    // *** STATE VARIABLES ***

    // Fee recipient
    address treasury;

    // Address of the TFM that controls this manager
    address actionLayer;

    // Implementation for wallet proxies
    address walletImplementation;

    // Stores each user's wallet
    mapping(address => ITrufinWallet) public wallets;

    // Records how much collateral a user has allocated to a strategy
    // Maps user => strategy ID => amount
    mapping(address => mapping(uint256 => Allocation)) public collaterals;

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

    modifier actionLayerOnly() {
        require(msg.sender == actionLayer, "ASSET LAYER: Action layer only");
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

    // *** GETTERS ***

    /// @notice Gets the amount of collateral a user has allocated to a specific strategy position.
    /// @param _position True for alpha, false for omega.
    function getAllocation(
        address _user,
        uint256 _strategyId,
        bool _position
    ) external view returns (uint256 allocation) {
        if (_position) {
            allocation = collaterals[_user][_strategyId].alphaBalance;
        } else {
            allocation = collaterals[_user][_strategyId].omegaBalance;
        }
    }

    // *** WALLET CREATION ***

    // Deploys a new wallet for the caller if they do not have one
    function createWallet() external {
        require(address(wallets[msg.sender]) == address(0), "COLLATERAL MANAGER: Caller has wallet already");

        // Deploy proxy & initialize
        ITrufinWallet wallet = ITrufinWallet(Clones.clone(walletImplementation));
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

    function setActionLayer(address _actionLayer) external onlyOwner {
        actionLayer = _actionLayer;
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
    ) external actionLayerOnly {
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

    function executePeppermint(ExecutePeppermintParameters calldata _parameters) external actionLayerOnly {
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

    // Ensure correct collateral and security flow when transferring to self
    function executeTransfer(ExecuteTransferParameters calldata _parameters) external actionLayerOnly {
        uint256 requirementRecipient = _parameters.recipientCollateralRequirement + _parameters.recipientFee;
        uint256 requirementSender = _parameters.senderFee;

        uint256 availableRecipient = reserves[_parameters.recipient][_parameters.basis];
        uint256 availableSender = reserves[_parameters.sender][_parameters.basis] +
            (
                _parameters.alphaTransfer
                    ? collaterals[_parameters.sender][_parameters.strategyId].alphaBalance
                    : collaterals[_parameters.sender][_parameters.strategyId].omegaBalance
            );

        {
            // Premium transferred before collateral locked and fee taken
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
            collaterals[_parameters.sender][_parameters.strategyId].alphaBalance = 0;
            collaterals[_parameters.recipient][_parameters.strategyId].alphaBalance = _parameters
                .recipientCollateralRequirement;
        } else {
            collaterals[_parameters.sender][_parameters.strategyId].omegaBalance = 0;
            collaterals[_parameters.recipient][_parameters.strategyId].omegaBalance = _parameters
                .recipientCollateralRequirement;
        }

        // Update transferring parties' reserves
        reserves[_parameters.recipient][_parameters.basis] = availableRecipient - requirementRecipient;
        reserves[_parameters.sender][_parameters.basis] = availableSender - requirementSender;
    }

    function executeCombination(ExecuteCombinationParameters calldata _parameters) external actionLayerOnly {
        uint256 availableAlphaOne;
        uint256 availableOmegaOne;

        // Perform aligment-specific logic
        if (_parameters.aligned) {
            availableAlphaOne =
                reserves[_parameters.alphaOne][_parameters.basis] +
                collaterals[_parameters.alphaOne][_parameters.strategyOneId].alphaBalance +
                collaterals[_parameters.alphaOne][_parameters.strategyTwoId].alphaBalance;

            availableOmegaOne =
                reserves[_parameters.omegaOne][_parameters.basis] +
                collaterals[_parameters.omegaOne][_parameters.strategyOneId].omegaBalance +
                collaterals[_parameters.omegaOne][_parameters.strategyTwoId].omegaBalance;

            delete collaterals[_parameters.alphaOne][_parameters.strategyTwoId].alphaBalance;
            delete collaterals[_parameters.omegaOne][_parameters.strategyTwoId].omegaBalance;
        } else {
            availableAlphaOne =
                reserves[_parameters.alphaOne][_parameters.basis] +
                collaterals[_parameters.alphaOne][_parameters.strategyOneId].alphaBalance +
                collaterals[_parameters.alphaOne][_parameters.strategyTwoId].omegaBalance;
            availableOmegaOne =
                reserves[_parameters.omegaOne][_parameters.basis] +
                collaterals[_parameters.omegaOne][_parameters.strategyOneId].omegaBalance +
                collaterals[_parameters.omegaOne][_parameters.strategyTwoId].alphaBalance;

            delete collaterals[_parameters.alphaOne][_parameters.strategyTwoId].omegaBalance;
            delete collaterals[_parameters.omegaOne][_parameters.strategyTwoId].alphaBalance;
        }

        // Update reserves
        reserves[_parameters.alphaOne][_parameters.basis] =
            availableAlphaOne -
            _parameters.resultingAlphaCollateralRequirement;
        reserves[_parameters.omegaOne][_parameters.basis] =
            availableOmegaOne -
            _parameters.resultingOmegaCollateralRequirement;

        // Set collateral allocations on combined strategy
        collaterals[_parameters.alphaOne][_parameters.strategyOneId].alphaBalance = _parameters
            .resultingAlphaCollateralRequirement;
        collaterals[_parameters.omegaOne][_parameters.strategyOneId].omegaBalance = _parameters
            .resultingOmegaCollateralRequirement;

        // Transfer fees
        _transferFromWallet(_parameters.basis, _parameters.alphaOne, treasury, _parameters.alphaOneFee);
        _transferFromWallet(_parameters.basis, _parameters.omegaOne, treasury, _parameters.omegaOneFee);
    }

    function executeNovation() external actionLayerOnly {}

    // Potential DoS => allocation is less than payout => liquidation is required
    function executeExercise(
        uint256 _strategyId,
        address _alpha,
        address _omega,
        address _basis,
        int256 _payout
    ) external actionLayerOnly {
        uint256 absolutePayout;
        if (_payout > 0) {
            absolutePayout = uint256(_payout);

            reserves[_alpha][_basis] += collaterals[_alpha][_strategyId].alphaBalance - absolutePayout;
            reserves[_omega][_basis] += absolutePayout + collaterals[_omega][_strategyId].omegaBalance;

            _transferFromWallet(_basis, _alpha, address(wallets[_omega]), absolutePayout);
        } else {
            absolutePayout = uint256(-_payout);

            reserves[_alpha][_basis] += absolutePayout + collaterals[_alpha][_strategyId].alphaBalance;
            reserves[_omega][_basis] += collaterals[_omega][_strategyId].omegaBalance - absolutePayout;

            _transferFromWallet(_basis, _omega, address(wallets[_alpha]), absolutePayout);
        }

        // Delete exercised strategy collaterals
        delete collaterals[_alpha][_strategyId].alphaBalance;
        delete collaterals[_omega][_strategyId].omegaBalance;
    }

    function executeLiquidation(
        uint256 _strategyId,
        address _alpha,
        address _omega,
        int256 _compensation,
        address _basis,
        uint256 _alphaPenalisation,
        uint256 _omegaPenalisation
    ) external actionLayerOnly {
        uint256 alphaReduction;
        uint256 omegaReduction;

        uint256 absoluteCompensation;

        // Transfer any compensation
        if (_compensation > 0) {
            absoluteCompensation = uint256(_compensation);

            reserves[_omega][_basis] += absoluteCompensation;

            alphaReduction = absoluteCompensation;

            _transferFromWallet(_basis, _alpha, address(wallets[_omega]), absoluteCompensation);
        } else if (_compensation < 0) {
            absoluteCompensation = uint256(-_compensation);

            reserves[_alpha][_basis] += absoluteCompensation;

            omegaReduction = absoluteCompensation;

            _transferFromWallet(_basis, _omega, address(wallets[_alpha]), absoluteCompensation);
        }

        // Transfer penalisations to treasury
        if (_alphaPenalisation > 0) {
            alphaReduction += _alphaPenalisation;

            _transferFromWallet(_basis, _alpha, treasury, _alphaPenalisation);
        }
        if (_omegaPenalisation > 0) {
            omegaReduction += _omegaPenalisation;

            _transferFromWallet(_basis, _omega, treasury, _omegaPenalisation);
        }

        collaterals[_alpha][_strategyId].alphaBalance -= alphaReduction;
        collaterals[_omega][_strategyId].omegaBalance -= omegaReduction;
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
    // Reserve/peppermint deposit updates are carried out in the calling function
    function _sharedMintLogic(
        SharedMintLogicParameters memory _parameters
    ) internal returns (uint256 alphaRemaining, uint256 omegaRemaining) {
        // Set strategy collaterals
        collaterals[_parameters.alpha][_parameters.strategyId].alphaBalance = _parameters.alphaCollateralRequirement;
        collaterals[_parameters.omega][_parameters.strategyId].omegaBalance = _parameters.omegaCollateralRequirement;

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

    // Grants owner upgrade authorization
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
