// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../interfaces/ICollateralManager.sol";
import "./PersonalPool.sol";
import "../misc/Types.sol";

contract CollateralManager is
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    ICollateralManager
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

    // Records how many unallocated basis tokens a user has available
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

        treasury = _treasury;
    }

    // *** ADMIN SETTERS ***

    function setTFM(address _tfm) external onlyOwner {
        tfm = _tfm;
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    /// *** USER COLLATERAL MANAGEMENT ***

    // Deposit basis tokens into unallocated collateral balance
    function deposit(address _basis, uint256 amount) external {
        address payable pool = _getOrCreatePersonalPool(msg.sender);

        IERC20(_basis).safeTransferFrom(msg.sender, pool, amount);

        unallocatedCollateral[msg.sender][_basis] += amount;

        emit Deposit(msg.sender, _basis, amount);
    }

    // Withdraw unallocated basis tokens
    function withdraw(address _basis, uint256 amount) external {
        unallocatedCollateral[msg.sender][_basis] -= amount;

        address payable pool = _getOrCreatePersonalPool(msg.sender);

        PersonalPool(pool).transferERC20(_basis, msg.sender, amount);

        emit Withdrawal(msg.sender, _basis, amount);
    }

    /// *** TFM METHODS ***

    function executeSpearmint(
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
        address payable alphaPool = _getOrCreatePersonalPool(_alpha);
        address payable omegaPool = _getOrCreatePersonalPool(_omega);

        unallocatedCollateral[_alpha][_basis] -=
            _alphaCollateralRequirement +
            _alphaFee;

        unallocatedCollateral[_omega][_basis] -=
            _omegaCollateralRequirement +
            _omegaFee;

        if (_premium > 0) {
            PersonalPool(alphaPool).transferERC20(
                _basis,
                omegaPool,
                uint256(_premium)
            );

            unallocatedCollateral[_alpha][_basis] -= uint256(_premium);
            unallocatedCollateral[_omega][_basis] += uint256(_premium);
        } else {
            PersonalPool(omegaPool).transferERC20(
                _basis,
                alphaPool,
                uint256(_premium)
            );

            unallocatedCollateral[_alpha][_basis] += uint256(_premium);
            unallocatedCollateral[_omega][_basis] -= uint256(_premium);
        }

        // Allocate required collateral to the new strategy
        allocatedCollateral[_alpha][_strategyId] += _alphaCollateralRequirement;
        allocatedCollateral[_omega][_strategyId] += _omegaCollateralRequirement;

        if (_alphaFee > 0) {
            _takeFee(_alpha, _basis, _alphaFee);
        }

        if (_omegaFee > 0) {
            _takeFee(_omega, _basis, _omegaFee);
        }
    }

    // function executeLiquidation(
    //     LiquidationParams calldata _liquidationParams,
    //     uint256 _strategyId,
    //     address _alpha,
    //     address _omega,
    //     address _basis
    // ) external isTFM {
    //     // Ensure liquidation parameters correspond to the parties' actual collateral allocations
    //     require(
    //         allocatedCollateral[_alpha][_strategyId] ==
    //             _liquidationParams.initialAlphaAllocation
    //     );
    //     require(
    //         allocatedCollateral[_omega][_strategyId] ==
    //             _liquidationParams.initialOmegaAllocation
    //     );

    //     uint256 alphaAllocatedCollateralReduction;
    //     uint256 omegaAllocatedCollateralReduction;

    //     // Fees

    //     if (_liquidationParams.alphaFee > 0) {
    //         PersonalPool(alphaPool).transferERC20(_basis, TreasuryAddress, _liquidationParams.alphaFee);
    //         alphaAllocatedCollateralReduction += _liquidationParams.alphaFee;
    //     }

    //     if (_liquidationParams.omegaFee >0) {
    //         PersonalPool(omegaPool).transferERC20(_basis, TreasuryAddress, _liquidationParams.omegaFee);
    //         omegaAllocatedCollateralReduction += _liquidationParams.omegaFee;
    //     }

    //     // Compensations

    //     if (_liquidationParams.alphaCompensation > 0) {
    //         PersonalPool(omegaPool).transferERC20(_basis, alphaPool, _liquidationParams.alphaCompensation);
    //         omegaAllocatedCollateralReduction += _liquidationParams.alphaCompensation;
    //         unallocatedCollateral[_alpha][_basis] += _liquidationParams.alphaCompensation;
    //     }

    //     if (_liquidationParams.omegaCompensation > 0) {
    //         PersonalPool(alphaPool).transferERC20(_basis, omegaPool, _liquidationParams.omegaCompensation);
    //         alphaAllocatedCollateralReduction += _liquidationParams.omegaCompensation;
    //         unallocatedCollateral[_omega][_basis] += _liquidationParams.omegaCompensation;
    //     }

    //     // Update allocations

    //     if (alphaAllocatedCollateralReduction > 0) {
    //         allocatedCollateral[_alpha][_strategyId] -= alphaAllocatedCollateralReduction;
    //     }

    //     if (omegaAllocatedCollateralReduction >0) {
    //         allocatedCollateral[_omega][_strategyId] -= omegaAllocatedCollateralReduction;
    //     }

    //     // Call new checkCollateralNonce method here
    //     checkCollateralNonce( _liquidationParams.collateralNonce);
    // }

    /// *** INTERNAL METHODS ***

    function _takeFee(address _user, address _basis, uint256 _fee) internal {
        address payable pool = _getOrCreatePersonalPool(_user);

        PersonalPool(pool).transferERC20(_basis, treasury, _fee);
    }

    function _getOrCreatePersonalPool(
        address _user
    ) internal returns (address payable) {
        address payable personalPool = personalPools[_user];
        if (personalPool == address(0)) {
            personalPool = payable(new PersonalPool());
            personalPools[_user] = personalPool;
        }
        return personalPool;
    }
}
