// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

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
    mapping(address => mapping(uint256 => uint256)) public allocatedCollateral;

    // Records how many unallocated basis tokens a user has available to provide as collateral
    // Maps user => basis => amount
    mapping(address => mapping(address => uint256)) public deposits;

    // Users escrow tokens to be used by a specific pepperminter
    // Maps user => pepperminter => basis => deposit ID => deposit
    mapping(address => mapping(address => mapping(address => mapping(uint256 => PeppermintDeposit))))
        public peppermintDeposits;

    // Incrementing counters used to genenerate IDs that facilitate multiple deposits to the same pepperminter
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

        deposits[msg.sender][_basis] += _amount;

        emit Deposit(msg.sender, _basis, _amount);
    }

    // Withdraw unallocated basis tokens
    function withdraw(address _basis, uint256 amount) external {
        deposits[msg.sender][_basis] -= amount;

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

        delete peppermintDeposits[msg.sender][_pepperminter][_basis][_peppermintDepositId];

        emit PeppermintWithdrawal(msg.sender, _pepperminter, _basis, _peppermintDepositId, amount);
    }

    // *** ADMIN SETTERS ***

    function setTFM(address _tfm) external onlyOwner {
        tfm = _tfm;
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    // *** TFM COLLATERAL FUNCTIONALITY ***

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
    ) external tfmOnly {
        // Cache wallets
        IWallet alphaWallet = wallets[_alpha];
        IWallet omegaWallet = wallets[_omega];

        // Process premium (could put this in internal method if used elsewhere)
        if (_premium > 0) {
            deposits[_alpha][_basis] -= uint256(_premium);
            deposits[_alpha][_basis] += uint256(_premium);

            _transferFromWallet(alphaWallet, _basis, address(omegaWallet), _alphaFee);
        } else {
            deposits[_alpha][_basis] += uint256(_premium);
            deposits[_alpha][_basis] -= uint256(_premium);

            _transferFromWallet(omegaWallet, _basis, address(alphaWallet), _alphaFee);
        }

        deposits[_alpha][_basis] -= _alphaCollateralRequirement + _alphaFee;
        deposits[_omega][_basis] -= _omegaCollateralRequirement + _omegaFee;

        // Set strategy allocations
        allocatedCollateral[_alpha][_strategyId] = _alphaCollateralRequirement;
        allocatedCollateral[_omega][_strategyId] = _omegaCollateralRequirement;

        // Transfer fees (fees are always non-zero)
        _transferFromWallet(alphaWallet, _basis, treasury, _alphaFee);
        _transferFromWallet(omegaWallet, _basis, treasury, _omegaFee);
    }

    // Transfers ERC20 tokens from a user's wallet to a recipient address
    function _transferFromWallet(address _user, address _token, address _recipient, uint256 _amount) internal {
        wallets[_user].transferERC20(_token, _recipient, _amount);
    }

    // Transfers ERC20 tokens from a user's wallet to a recipient address
    function _transferFromWallet(IWallet _wallet, address _token, address _recipient, uint256 _amount) internal {
        _wallet.transferERC20(_token, _recipient, _amount);
    }

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
        // // Cache personal pool addresses
        // address payable senderPool = _getWallet(_sender);
        // address payable recipientPool = _getWallet(_recipient);
        // _transferPremium(_sender, _recipient, senderPool, recipientPool, _basis, _premium);
        // // Unallocate collateral sender has allocated to the strategy
        // deposits[_sender][_basis] += allocatedCollateral[_sender][_strategyId];
        // allocatedCollateral[_sender][_strategyId] = 0;
        // // Allocate recipient's collateral to the strategy
        // deposits[_recipient][_basis] -= recipientCollateralRequirement;
        // allocatedCollateral[_recipient][_strategyId] += recipientCollateralRequirement;
        // // Register fee payment
        // deposits[_sender][_basis] -= _senderFee;
        // deposits[_recipient][_basis] -= _recipientFee;
        // // Take protocol fee
        // _transferFromPersonalPool(senderPool, _basis, treasury, _senderFee);
        // _transferFromPersonalPool(recipientPool, _basis, treasury, _recipientFee);
    }

    // Aligned is not needed => as allocated maps user address => strategy ID => amount of tokens
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
    ) external tfmOnly {
        // Get each combiners available collateral for their position on the combined strategy
        // uint256 availableStrategyOneAlpha = deposits[_strategyOneAlpha][_basis] +
        //     allocatedCollateral[_strategyOneAlpha][_strategyOneId] +
        //     allocatedCollateral[_strategyOneAlpha][_strategyTwoId];
        // uint256 availableStrategyOneOmega = deposits[_strategyOneOmega][_basis] +
        //     allocatedCollateral[_strategyOneOmega][_strategyOneId] +
        //     allocatedCollateral[_strategyOneOmega][_strategyTwoId];
        // // Set strategy one allocations
        // allocatedCollateral[_strategyOneAlpha][_strategyOneId] = _resultingAlphaCollateralRequirement;
        // allocatedCollateral[_strategyOneOmega][_strategyTwoId] = _resultingOmegaCollateralRequirement;
        // // Set unallocated collateral
        // deposits[_strategyOneAlpha][_basis] =
        //     availableStrategyOneAlpha -
        //     _resultingAlphaCollateralRequirement -
        //     _strategyOneAlphaFee;
        // deposits[_strategyOneOmega][_basis] =
        //     availableStrategyOneOmega -
        //     _resultingOmegaCollateralRequirement -
        //     _strategyOneOmegaFee;
        // _transferFromUsersPool(_strategyOneAlpha, _basis, treasury, _strategyOneAlphaFee);
        // _transferFromUsersPool(_strategyOneOmega, _basis, treasury, _strategyOneOmegaFee);
        // delete allocatedCollateral[_strategyOneAlpha][_strategyTwoId];
        // delete allocatedCollateral[_strategyOneOmega][_strategyTwoId];
    }

    // Use an enum
    // Do non middle parties collateral requirements change? NO -> but they may be swapped
    function novate(
        uint256 _strategyOneId,
        uint256 _strategyTwoId,
        address _strategyOneAlpha,
        address _middleParty,
        address _strategyTwoOmega,
        address _basis,
        uint256 _resultingStrategyOneAlphaCollateralRequirement,
        uint256 _fee,
        uint256 _strategyTwoResultingAmplitiude
    ) external tfmOnly {
        // We need to free remaining collateral
        // Can assume new collateral requirements are less than allocated collaterals => is this true?
        // deposits[_strategyOneAlpha][_basis] += allocatedCollateral[_strategyOneAlpha][_strategyOneId];
        // allocatedCollateral[_strategyOneAlpha][_strategyOneId] = _resultingStrategyOneAlphaCollateralRequirement;
        // allocatedCollateral[_middleParty][_strategyOneId] = _resultingStrategyOneOmegaCollateralRequirement;
        // if (_strategyTwoResultingAmplitiude != 0) {
        //     allocatedCollateral[_middleParty][_strategyTwoId] = _resultingStrategyTwoAlphaCollateralRequirement;
        //     allocatedCollateral[_strategyTwoOmega][_strategyTwoId] = _resultingStrategyTwoOmegaCollateralRequirement;
        // } else {
        //     delete allocatedCollateral[_middleParty][_strategyTwoId];
        //     delete allocatedCollateral[_strategyTwoOmega][_strategyTwoId];
        // }
        // // Transfer fee
        // deposits[_middleParty][_basis] -= _fee;
        // // Maybe this should update deposits (as above?)
        // _transferFromUsersPool(_middleParty, _basis, treasury, _fee);
    }

    // Potential DoS if opposition does not have enough allocated collateral - if the fee is greater than their post payout collateral
    function exercise(
        uint256 _strategyId,
        address _alpha,
        address _omega,
        address _basis,
        int256 _payout
    ) external tfmOnly {
        // // Transfer payout and unallocate all remaining collateral
        // if (_payout > 0) {
        //     deposits[_alpha][_basis] = allocatedCollateral[_alpha][_strategyId] - uint256(_payout);
        //     deposits[_omega][_basis] += uint256(_payout) + allocatedCollateral[_omega][_strategyId];
        //     _transferBetweenUsers(_alpha, _omega, _basis, uint256(_payout));
        // } else {
        //     // What if they already have unallocated collateral in their basket
        //     deposits[_alpha][_basis] += uint256(-_payout) + allocatedCollateral[_alpha][_strategyId];
        //     deposits[_omega][_basis] = allocatedCollateral[_omega][_strategyId] - uint256(-_payout);
        //     _transferBetweenUsers(_omega, _alpha, _basis, uint256(-_payout));
        // }
        // // Delete state to add gas reduction
        // allocatedCollateral[_alpha][_strategyId] = 0;
        // allocatedCollateral[_omega][_strategyId] = 0;
    }

    // LIQUIDATE

    // Fees are taken from the liquidator's collateral => not from unallocated pool as per usual => RENAME
    function liquidate(
        uint256 _strategyId,
        address _alpha,
        address _omega,
        int256 _compensation,
        address _basis,
        uint256 _alphaPenalisation,
        uint256 _omegaPenalisation
    ) external {
        // address payable alphaPersonalPool = _getWallet(_alpha);
        // address payable omegaPersonalPool = _getWallet(_omega);
        // // Cache to avoid multiple storage writes
        // uint256 alphaAllocatedCollateralReduction;
        // uint256 omegaAllocatedCollateralReduction;
        // // Process any compensation
        // if (_compensation > 0) {
        //     _transferFromPersonalPool(alphaPersonalPool, _basis, omegaPersonalPool, uint256(_compensation));
        //     deposits[_omega][_basis] += uint256(_compensation);
        //     alphaAllocatedCollateralReduction = uint256(_compensation);
        // } else if (_compensation < 0) {
        //     _transferFromPersonalPool(omegaPersonalPool, _basis, alphaPersonalPool, uint256(-_compensation));
        //     deposits[_alpha][_basis] += uint256(-_compensation);
        //     omegaAllocatedCollateralReduction = uint256(-_compensation);
        // }
        // // Transfer protocol fees
        // if (_alphaPenalisation > 0) {
        //     _transferFromPersonalPool(alphaPersonalPool, _basis, treasury, _alphaPenalisation);
        //     allocatedCollateral[_alpha][_strategyId] -= _alphaPenalisation;
        // }
        // if (_alphaPenalisation > 0) {
        //     _transferFromPersonalPool(omegaPersonalPool, _basis, treasury, _omegaPenalisation);
        //     allocatedCollateral[_omega][_strategyId] -= _omegaPenalisation;
        // }
        // allocatedCollateral[_alpha][_strategyId] -= alphaAllocatedCollateralReduction;
        // allocatedCollateral[_omega][_strategyId] -= omegaAllocatedCollateralReduction;
    }

    /// *** INTERNAL METHODS ***

    // // Transfers ERC20 tokens from an input personal pool to a recipient
    // function _transferFromPersonalPool(
    //     address payable _pool,
    //     address _token,
    //     address _recipient,
    //     uint256 _amount
    // ) internal {
    //     IWallet(_pool).transferERC20(_token, _recipient, _amount);
    // }

    // // Transfers ERC20 tokens from a user's personal pool to a recipient
    // function _transferFromUsersPool(address _user, address _token, address _recipient, uint256 _amount) internal {
    //     address payable pool = _getWallet(_user);

    //     IWallet(pool).transferERC20(_token, _recipient, _amount);
    // }

    // // Transfer ERC20 tokens from one pool to another
    // function _transferBetweenUsers(address _userOne, address _userTwo, address _basis, uint256 _amount) internal {
    //     address payable userOnePool = _getWallet(_userOne);
    //     address payable userTwoPool = _getWallet(_userTwo);

    //     IWallet(userOnePool).transferERC20(_basis, userTwoPool, _amount);
    // }

    // Same as above but takes in pools instead of addresses
    // function _transferBetweenPools()

    // // Execute a premium transfer between two parties
    // function _transferPremium(
    //     address _partyOne,
    //     address _partyTwo,
    //     address payable _partyOnePool,
    //     address payable _partyTwoPool,
    //     address _basis,
    //     int256 _premium
    // ) internal {
    //     if (_premium > 0) {
    //         IWallet(_partyOnePool).transferERC20(_basis, _partyTwoPool, uint256(_premium));

    //         deposits[_partyOne][_basis] -= uint256(_premium);
    //         deposits[_partyTwo][_basis] += uint256(_premium);
    //     } else if (_premium < 0) {
    //         IWallet(_partyTwoPool).transferERC20(_basis, _partyOnePool, uint256(-_premium));

    //         deposits[_partyOne][_basis] += uint256(-_premium);
    //         deposits[_partyTwo][_basis] -= uint256(-_premium);
    //     }
    // }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
