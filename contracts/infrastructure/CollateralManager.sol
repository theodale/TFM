// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interfaces/ICollateralManager.sol";
import "./PersonalPool.sol";
import "../misc/Types.sol";

import "hardhat/console.sol";

contract CollateralManager is
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    ICollateralManager,
    UUPSUpgradeable
{
    // *** LIBRARIES ***

    using SafeERC20 for IERC20;

    // *** STATE VARIABLES ***

    // Address fees are sent to
    address treasury;

    // Address of the protocol's TFM contract
    address tfm;

    // Stores the address of each user's personal pool
    mapping(address => address payable) public personalPools;

    // Records how much collateral a party has allocated to a strategy
    // Maps user address => strategy ID => amount of tokens
    mapping(address => mapping(uint256 => uint256)) public allocatedCollateral;

    // Records how many unallocated basis tokens a user has available to provide as collateral
    // Maps user address => token address => amount of tokens
    mapping(address => mapping(address => uint256))
        public unallocatedCollateral;

    /// *** MODIFIERS ***

    modifier tfmOnly() {
        require(msg.sender == tfm, "CollateralManager: TFM only");
        _;
    }

    // *** INITIALIZER ***

    function initialize(
        address _treasury,
        address _owner
    ) external initializer {
        // Initialize parent state
        __ReentrancyGuard_init();
        __Ownable_init();
        transferOwnership(_owner);
        __UUPSUpgradeable_init();

        treasury = _treasury;
    }

    // *** ADMIN SETTERS ***

    function setTFM(address _tfm) external onlyOwner {
        tfm = _tfm;
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    // *** USER COLLATERAL MANAGEMENT ***

    // Deposit basis tokens into unallocated collateral balance
    function deposit(address _basis, uint256 amount) external {
        address payable pool = _getPersonalPool(msg.sender);

        IERC20(_basis).safeTransferFrom(msg.sender, pool, amount);

        unallocatedCollateral[msg.sender][_basis] += amount;

        emit Deposit(msg.sender, _basis, amount);
    }

    // Withdraw unallocated basis tokens
    function withdraw(address _basis, uint256 amount) external {
        unallocatedCollateral[msg.sender][_basis] -= amount;

        _transferFromUsersPool(msg.sender, _basis, msg.sender, amount);

        emit Withdrawal(msg.sender, _basis, amount);
    }

    // *** TFM COLLATERAL METHODS ***

    // Premium transferred before collateral locked and fee taken
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
        // Cache personal pool addresses
        address payable alphaPool = _getPersonalPool(_alpha);
        address payable omegaPool = _getPersonalPool(_omega);

        _transferPremium(
            _alpha,
            _omega,
            alphaPool,
            omegaPool,
            _basis,
            _premium
        );

        // Take fee and required collateral from unallocated minter collateral
        unallocatedCollateral[_alpha][_basis] -=
            _alphaCollateralRequirement +
            _alphaFee;
        unallocatedCollateral[_omega][_basis] -=
            _omegaCollateralRequirement +
            _omegaFee;

        // Allocate required collateral to the new strategy
        allocatedCollateral[_alpha][_strategyId] += _alphaCollateralRequirement;
        allocatedCollateral[_omega][_strategyId] += _omegaCollateralRequirement;

        // Transfer tokens taken as a fee from personal pools to treasury
        if (_alphaFee > 0) {
            _transferFromPersonalPool(alphaPool, _basis, treasury, _alphaFee);
        }
        if (_omegaFee > 0) {
            _transferFromPersonalPool(omegaPool, _basis, treasury, _omegaFee);
        }
    }

    // Premium trasnferred before collateral locked and fee taken
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
        // Cache personal pool addresses
        address payable senderPool = _getPersonalPool(_sender);
        address payable recipientPool = _getPersonalPool(_recipient);

        _transferPremium(
            _sender,
            _recipient,
            senderPool,
            recipientPool,
            _basis,
            _premium
        );

        // Unallocate collateral sender has allocated to the strategy
        unallocatedCollateral[_sender][_basis] += allocatedCollateral[_sender][
            _strategyId
        ];
        allocatedCollateral[_sender][_strategyId] = 0;

        // Allocate recipient's collateral to the strategy
        unallocatedCollateral[_recipient][
            _basis
        ] -= recipientCollateralRequirement;
        allocatedCollateral[_recipient][
            _strategyId
        ] += recipientCollateralRequirement;

        // Register fee payment
        unallocatedCollateral[_sender][_basis] -= _senderFee;
        unallocatedCollateral[_recipient][_basis] -= _recipientFee;

        // Take protocol fee
        _transferFromPersonalPool(senderPool, _basis, treasury, _senderFee);
        _transferFromPersonalPool(
            recipientPool,
            _basis,
            treasury,
            _recipientFee
        );
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
        uint256 availableStrategyOneAlpha = unallocatedCollateral[
            _strategyOneAlpha
        ][_basis] +
            allocatedCollateral[_strategyOneAlpha][_strategyOneId] +
            allocatedCollateral[_strategyOneAlpha][_strategyTwoId];
        uint256 availableStrategyOneOmega = unallocatedCollateral[
            _strategyOneOmega
        ][_basis] +
            allocatedCollateral[_strategyOneOmega][_strategyOneId] +
            allocatedCollateral[_strategyOneOmega][_strategyTwoId];

        // Set strategy one allocations
        allocatedCollateral[_strategyOneAlpha][
            _strategyOneId
        ] = _resultingAlphaCollateralRequirement;
        allocatedCollateral[_strategyOneOmega][
            _strategyTwoId
        ] = _resultingOmegaCollateralRequirement;

        // Set unallocated collateral
        unallocatedCollateral[_strategyOneAlpha][_basis] =
            availableStrategyOneAlpha -
            _resultingAlphaCollateralRequirement -
            _strategyOneAlphaFee;
        unallocatedCollateral[_strategyOneOmega][_basis] =
            availableStrategyOneOmega -
            _resultingOmegaCollateralRequirement -
            _strategyOneOmegaFee;

        _transferFromUsersPool(
            _strategyOneAlpha,
            _basis,
            treasury,
            _strategyOneAlphaFee
        );

        _transferFromUsersPool(
            _strategyOneOmega,
            _basis,
            treasury,
            _strategyOneOmegaFee
        );

        delete allocatedCollateral[_strategyOneAlpha][_strategyTwoId];
        delete allocatedCollateral[_strategyOneOmega][_strategyTwoId];
    }

    // Potential DoS if opposition does not have enough allocated collateral - if the fee is greater than their post payout collateral
    function exercise(
        uint256 _strategyId,
        address _alpha,
        address _omega,
        address _basis,
        int256 _payout,
        uint256 _alphaFee,
        uint256 _omegaFee
    ) external tfmOnly {
        // Transfer payout and unallocate all remaining collateral
        if (_payout > 0) {
            unallocatedCollateral[_alpha][_basis] =
                allocatedCollateral[_alpha][_strategyId] -
                uint256(_payout);
            unallocatedCollateral[_omega][_basis] +=
                uint256(_payout) +
                allocatedCollateral[_omega][_strategyId];
        } else {
            unallocatedCollateral[_alpha][_basis] +=
                uint256(-_payout) +
                allocatedCollateral[_alpha][_strategyId];
            unallocatedCollateral[_omega][_basis] =
                allocatedCollateral[_omega][_strategyId] -
                uint256(-_payout);
        }

        // address alphaPool = _getPersonalPool();

        // Take fees
        unallocatedCollateral[_alpha][_basis] -= _alphaFee;
        unallocatedCollateral[_omega][_basis] -= _omegaFee;

        // Still need to transfer premium and fees from user pools

        // Delete state to add gas reduction
        allocatedCollateral[_alpha][_strategyId] = 0;
        allocatedCollateral[_omega][_strategyId] = 0;
    }

    // LIQUIDATE

    // LIQUIDATE

    function liquidate(
        uint256 _strategyId,
        address _alpha,
        address _omega,
        int256 _compensation,
        address _basis,
        uint256 _alphaFee,
        uint256 _omegaFee
    ) external {
        // uint256 alphaAllocatedCollateralReduction;
        // uint256 omegaAllocatedCollateralReduction;
        // Fees
        // if (_liquidationParams.alphaFee > 0) {
        //     PersonalPool(alphaPool).transferERC20(
        //         _basis,
        //         TreasuryAddress,
        //         _liquidationParams.alphaFee
        //     );
        //     alphaAllocatedCollateralReduction += _liquidationParams.alphaFee;
        // }
        // if (_liquidationParams.omegaFee > 0) {
        //     PersonalPool(omegaPool).transferERC20(
        //         _basis,
        //         TreasuryAddress,
        //         _liquidationParams.omegaFee
        //     );
        //     omegaAllocatedCollateralReduction += _liquidationParams.omegaFee;
        // }
        // Compensations
        // if (_liquidationParams.alphaCompensation > 0) {
        //     PersonalPool(omegaPool).transferERC20(
        //         _basis,
        //         alphaPool,
        //         _liquidationParams.alphaCompensation
        //     );
        //     omegaAllocatedCollateralReduction += _liquidationParams
        //         .alphaCompensation;
        //     unallocatedCollateral[_alpha][_basis] += _liquidationParams
        //         .alphaCompensation;
        // }
        // if (_liquidationParams.omegaCompensation > 0) {
        //     PersonalPool(alphaPool).transferERC20(
        //         _basis,
        //         omegaPool,
        //         _liquidationParams.omegaCompensation
        //     );
        //     alphaAllocatedCollateralReduction += _liquidationParams
        //         .omegaCompensation;
        //     unallocatedCollateral[_omega][_basis] += _liquidationParams
        //         .omegaCompensation;
        // }
        // Update allocations
        // if (alphaAllocatedCollateralReduction > 0) {
        //     allocatedCollateral[_alpha][
        //         _strategyId
        //     ] -= alphaAllocatedCollateralReduction;
        // }
        // if (omegaAllocatedCollateralReduction > 0) {
        //     allocatedCollateral[_omega][
        //         _strategyId
        //     ] -= omegaAllocatedCollateralReduction;
        // }
    }

    /// *** INTERNAL METHODS ***

    // Possibly refactor in future => we may be able to assume that a personal pool already exists for the user in certain scenarios
    function _getPersonalPool(
        address _user
    ) internal returns (address payable) {
        address payable personalPool = personalPools[_user];

        // Deploy new personal pool for user if they have not got one
        if (personalPool == address(0)) {
            personalPool = payable(new PersonalPool());

            personalPools[_user] = personalPool;
        }

        return personalPool;
    }

    // Transfers ERC20 tokens from an input personal pool to a recipient
    function _transferFromPersonalPool(
        address payable _pool,
        address _token,
        address _recipient,
        uint256 _amount
    ) internal {
        PersonalPool(_pool).transferERC20(_token, _recipient, _amount);
    }

    // Transfers ERC20 tokens from a user's personal pool to a recipient
    function _transferFromUsersPool(
        address _user,
        address _token,
        address _recipient,
        uint256 _amount
    ) internal {
        address payable pool = _getPersonalPool(_user);

        PersonalPool(pool).transferERC20(_token, _recipient, _amount);
    }

    // Execute a premium transfer between two parties
    function _transferPremium(
        address _partyOne,
        address _partyTwo,
        address payable _partyOnePool,
        address payable _partyTwoPool,
        address _basis,
        int256 _premium
    ) internal {
        if (_premium > 0) {
            PersonalPool(_partyOnePool).transferERC20(
                _basis,
                _partyTwoPool,
                uint256(_premium)
            );

            unallocatedCollateral[_partyOne][_basis] -= uint256(_premium);
            unallocatedCollateral[_partyTwo][_basis] += uint256(_premium);
        } else if (_premium < 0) {
            PersonalPool(_partyTwoPool).transferERC20(
                _basis,
                _partyOnePool,
                uint256(-_premium)
            );

            unallocatedCollateral[_partyOne][_basis] += uint256(-_premium);
            unallocatedCollateral[_partyTwo][_basis] -= uint256(-_premium);
        }
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
