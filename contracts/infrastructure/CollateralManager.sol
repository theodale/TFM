// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {ICollateralManager} from "../interfaces/ICollateralManager.sol";
import {PersonalPool} from "./PersonalPool.sol";
import "../misc/Types.sol";

contract CollateralManager is
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable
    ICollateralManager
{
    // Libraries
    using SafeERC20 for IERC20;

    // State Variables
    address treasury;
    address trufinOracle;
    address tfm;

    mapping(address => address) public personalPools;

    // Records how much collateral a party has allocated to a strategy
    // Maps user address => strategy ID => amount of tokens
    mapping(address => mapping(uint256 => uint256)) public allocatedCollateral;

    // Records how many unallocated basis tokens a user has available
    // Maps user address => token address => amount of tokens
    mapping(address => mapping(address => uint256))
        public unallocatedCollateral;

    // address immutable weth;

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

    // *** SETTERS ***

    // Admin method to set new TFM address
    function setTFM(address _tfm) external onlyOwner {
        tfm = _tfm;
    }

    // Admin method to set new treasury address
    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

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

    //     bool bothSideAreSame = !_req.isTransfer && (_req.sender1 == _req.alpha) && (_req.sender1 == _req.omega);
    //     //if both side of strategy are same we should take maximum from collateral of each side
    //     uint256 requiredCollateral = bothSideAreSame ? Utils.max(
    //             _req.alphaCollateralRequirement,
    //             _req.omegaCollateralRequirement)
    //         : (_req.sender1 == _req.alpha ? _req.alphaCollateralRequirement
    //             : _req.omegaCollateralRequirement);

    //     // Allocate required collateral to newly minted strategy for sender1.
    //     _autoCollateraliseStrategy(
    //         _req.sender1,
    //         _req.strategyID,
    //         requiredCollateral,
    //         _req.basis
    //     );
    //     //ignore premium and second side transfers for both sides owned by same address
    //     if (!bothSideAreSame) {
    //         requiredCollateral =
    //                 _req.isAlpha
    //                     ? _req.alphaCollateralRequirement
    //                     : _req.omegaCollateralRequirement;

    //         // Collateralise strategy, covering any collateral and premium required.
    //         _autoCollateraliseStrategy(
    //             _req.sender2,
    //             _req.strategyID,
    //             requiredCollateral,
    //             _req.basis
    //         );

    //         // Transfer premium as required.
    //         if (_req.premium < 0)
    //             //slither-disable-next-line reentrancy-eth
    //             relocateUnallocatedCollateral(
    //                 _req.sender1,
    //                 _req.sender2,
    //                 _req.premium.abs(),
    //                 _req.basis
    //             );
    //         else if (_req.premium > 0) {
    //             //slither-disable-next-line reentrancy-eth
    //             relocateUnallocatedCollateral(
    //                 _req.sender2,
    //                 _req.sender1,
    //                 uint256(_req.premium),
    //                 _req.basis
    //             );
    //         }
    //         //charge particle mass for first side of strategy into TreasuryAddress. This peace of code is unreachable
    //         //when both side of
    //         //the strategy are same
    //         relocateUnallocatedCollateral(
    //             _req.sender1,
    //             TreasuryAddress,
    //             _req.particleMass,
    //             _req.basis
    //         );
    //     }
    //     // Transfer particle mass for second side
    //     relocateUnallocatedCollateral(
    //         _req.sender2,
    //         TreasuryAddress,
    //         //for both side of strategy are same we need to charge double fee
    //         bothSideAreSame ? _req.particleMass << 1 : _req.particleMass,
    //         _req.basis
    //     );
    // }

    // function initialize(
    //     address __owner,
    //     address _treasury,
    //     address _trufinOracle,
    //     address _tfm
    // ) external initializer {
    //     emit CollateralManagerInitialized();

    //     __ReentrancyGuard_init();
    //     __Ownable_init();
    //     transferOwnership(__owner);

    //     // Set relevant addresses
    //     treasury = _treasury;
    //     trufinOracle = _trufinOracle;
    //     tfm = _tfm;
    //     wrappedNativeCoin = _wrappedNativeCoin;
    // }

    // modifier isTFM() {
    //     require(msg.sender == TFMAddress, "CollateralManager: TFM only");
    //     _;
    // }

    // // Admin Setters

    // function setTFM(address _tfm) external onlyOwner {
    //     tfm = _tfm;
    //     emit TFMAddressUpdated(_tfm);
    // }

    // function setTreasury(address _treasury) external onlyOwner {
    //     treasury = _treasury;
    //     emit TreasuryAddressUpdated(_treasury);
    // }

    // // Collateral Management

    // /**
    //     @notice Function for a user to increase their unallocated collateral by moving funds into their personal pool.
    //             Funds will be moved, so CollateralManager should be allowed to spend _amount of _basis
    //     @param _basis basis of collateral posted
    //     @param _amount amount of collateral posted
    // */
    // function post(address _basis, uint256 _amount) external nonReentrant {
    //     require(_amount > 0, "C39");
    //     address personalPool = _getOrCreatePersonalPool(msg.sender);
    //     // slither-disable-next-line reentrancy-benign
    //     IERC20(_basis).safeTransferFrom(msg.sender, personalPool, _amount);
    //     unallocatedCollateral[msg.sender][_basis] += _amount;
    //     emit Posted(msg.sender, _basis, _amount, false);
    // }

    // /**
    //     @notice Function for a user to increase their unallocated collateral in the Native coin by wrapping it and
    //     moving funds into their personal pool.
    // */

    // function postNative() external payable nonReentrant {
    //     require(msg.value > 0, "C39");
    //     uint256 balanceOfNative = wrappedNativeCoin.balanceOf(address(this));
    //     // wrap native coin
    //     // slither-disable-next-line reentrancy-benign
    //     wrappedNativeCoin.deposit{value: msg.value}();
    //     // slither-disable-next-line reentrancy-benign
    //     require(
    //         wrappedNativeCoin.balanceOf(address(this)) - balanceOfNative >=
    //             msg.value,
    //         //hmm, we got less then deposited
    //         "C38"
    //     );
    //     address personalPool = _getOrCreatePersonalPool(msg.sender);
    //     require(wrappedNativeCoin.transfer(personalPool, msg.value), "C44");
    //     unallocatedCollateral[msg.sender][address(wrappedNativeCoin)] += msg
    //         .value;

    //     emit Posted(msg.sender, address(wrappedNativeCoin), msg.value, true);
    // }

    // /**
    //     @notice Function for a user to decrease its unallocated collateral by moving funds out of its personal pool.
    //     @param _basisAddress basis address of collateral withdrawn
    //     @param _amount amount of collateral withdrawn
    //     @param _isNative user wants to recieve payments in the Native coin
    // */
    // function withdraw(
    //     address _basisAddress,
    //     uint256 _amount,
    //     bool _isNative
    // ) external {
    //     require(
    //         !_isNative || (_basisAddress == address(wrappedNativeCoin)),
    //         "C40"
    //     );
    //     uint256 fee = TFM(TFMAddress).photons(_basisAddress);

    //     require(
    //         _amount + fee <= unallocatedCollateral[msg.sender][_basisAddress],
    //         "C11" // "amount greater than unallocated collateral"
    //     );
    //     unchecked {
    //         unallocatedCollateral[msg.sender][_basisAddress] -= (_amount + fee);
    //     }
    //     unallocatedCollateral[TreasuryAddress][_basisAddress] += fee;

    //     address payable personalPool = personalPools[msg.sender];
    //     address treasuryPool = _getOrCreatePersonalPool(TreasuryAddress);

    //     // send fees to Treasury address
    //     PersonalPool(personalPool).approve(_basisAddress, fee);
    //     // slither-disable-next-line arbitrary-send-erc20
    //     IERC20(_basisAddress).safeTransferFrom(personalPool, treasuryPool, fee);
    //     if (_isNative) {
    //         PersonalPool(personalPool).transferNative(
    //             payable(msg.sender),
    //             _amount
    //         );
    //     } else {
    //         PersonalPool(personalPool).approve(_basisAddress, _amount);
    //         // slither-disable-next-line arbitrary-send-erc20
    //         IERC20(_basisAddress).safeTransferFrom(
    //             personalPool,
    //             msg.sender,
    //             _amount
    //         );
    //     }
    //     emit Withdrawn(msg.sender, _basisAddress, _amount, _isNative);
    // }

    // // Relay address?

    // function updateCollateralNonce(
    //     uint256 _collateralNonce,
    //     bytes calldata _web2Sig
    // ) external {
    //     //we don't allow to decrease nonce
    //     require(_collateralNonce > collateralNonce, "C32");
    //     Utils.checkWebSignatureForNonce(
    //         _web2Sig,
    //         _collateralNonce,
    //         Web2Address
    //     );
    //     require((block.timestamp < latestCollateralNonceTime + MAX_TIME_UNTIL_LOCK) || (RelayAddress == msg.sender), "A5");
    //     collateralNonce = _collateralNonce;
    //     latestCollateralNonceTime = block.timestamp;

    //     emit UpdatedCollateralNonce(_collateralNonce);
    // }

    // /**
    //     @notice Function to check if the collateralNonce is valid. It also check that more
    //     than MAX_TIME_UNTIL_LOCK has not past since the last collateralNonce update
    //     @param _collateralNonce nonce to check is valid
    // */
    // function checkCollateralNonce(
    //     uint256 _collateralNonce
    // ) public view {
    //     require(
    //         (collateralNonce >= _collateralNonce) &&
    //             (collateralNonce - _collateralNonce <= 1),
    //         "C31"
    //     );
    //     require(
    //         (block.timestamp < latestCollateralNonceTime + MAX_TIME_UNTIL_LOCK),
    //         "C35" //collateralNonce has not been updated recently, contract locked
    //     );
    // }

    // /************************************************
    //  *  Collateral Locking
    //  ***********************************************/

    // /**
    //     @notice Function to change whether a locker is trusted or not.
    //     @dev a user's lockers can set collateralLocks on their unallocated collateral and use it in
    //     minting strategies on their behalf (using the TFM `peppermint` function)
    //     @param _locker address of locker to modify
    //     @param _trusted true to change the inputted _locker address to a trusted locker, false to
    //     remove it as a trusted locker
    // */
    // function changeTrustedLocker(address _locker, bool _trusted) external {
    //     if (_trusted) {
    //         trustedLockers[msg.sender][_locker] = true;
    //     } else {
    //         //free blockchain space
    //         delete trustedLockers[msg.sender][_locker];
    //     }
    //     emit ChangedTrustedLocker(msg.sender, _locker, _trusted);
    // }

    // /**
    //     @notice Function for a locker to increase a user's locked collateral (by setting or modifying a collateralLock).
    //     @param _user address of user getting locked
    //     @param _basis basis of the collateral lock
    //     @param _amount amount being locked
    //     @param _lockExpiry expiry of lock; this is when the user can call `unlockCollateral` to move the locked collateral
    //     back into their unallocated collateral pool
    // */
    // function increaseLockedCollateral(
    //     address _user,
    //     address _basis,
    //     uint256 _amount,
    //     uint256 _lockExpiry
    // ) external {
    //     require(
    //         trustedLockers[_user][msg.sender],
    //         "A31" // "msg.sender is not a trusted locker for user"
    //     );
    //     require(
    //         unallocatedCollateral[_user][_basis] >= _amount,
    //         "C11" // "user does not have enough unallocated collateral"
    //     );

    //     CollateralLock storage cl = lockedCollateral[_user][msg.sender][_basis];
    //     uint256 clLockExpiry = cl.lockExpiry;
    //     uint256 newLockExpiry = (clLockExpiry >= _lockExpiry)
    //         ? clLockExpiry
    //         : _lockExpiry;
    //     unchecked {
    //         unallocatedCollateral[_user][_basis] -= _amount;
    //     }
    //     cl.amount += _amount;
    //     cl.lockExpiry = newLockExpiry;

    //     emit IncreasedLockedCollateral(_user, _basis, _amount, _lockExpiry);
    // }

    // /**
    //     @notice Function for a locker to move collateral from a collateral lock to the user's unallocated collateral.
    //     If the collateral lock has already expired, this the user can also call `unlockCollateral`.
    //     @param _user user to unlock collateral of
    //     @param _locker locker to which locked collateral is assigned to in lockedCollateral mapping
    //     @param _basis basis of locked collateral
    //     @param _amount amount of collateral to unlock (what to reduce collateral lock's amount by)
    // */
    // function unlockCollateral(
    //     address _user,
    //     address _locker,
    //     address _basis,
    //     uint256 _amount
    // ) external {
    //     _unlockCollateral(msg.sender, _user, _locker, _basis, _amount);

    //     emit UnlockedCollateral(msg.sender, _user, _locker, _basis, _amount);
    // }

    // /**
    //     @notice Function for a locker to move collateral from a collateral lock to the user's unallocated collateral.
    //     If the collateral lock has already expired, this the user can also call `unlockCollateral`.
    //     @param _sender initiator, it can be _sender or _locker only.
    //     @param _user user to unlock collateral of
    //     @param _locker locker to which locked collateral is assigned to in lockedCollateral mapping
    //     @param _basis basis of locked collateral
    //     @param _amount amount of collateral to unlock (what to reduce collateral lock's amount by)
    // */

    // function _unlockCollateral(
    //     address _sender,
    //     address _user,
    //     address _locker,
    //     address _basis,
    //     uint256 _amount
    // ) internal {
    //     CollateralLock memory cl = lockedCollateral[_user][_locker][_basis];

    //     if (_sender == _user) {
    //         //slither-disable-next-line timestamp
    //         require(
    //             cl.lockExpiry <= block.timestamp,
    //             "C41" // "collateral lock has not yet expired"
    //         );
    //     } else {
    //         require(
    //             _sender == _locker,
    //             "A31" // "not authorised"
    //         );
    //     }

    //     require(
    //         cl.amount >= _amount,
    //         "C42" // "amount larger than locked amount"
    //     );
    //     unchecked {
    //         lockedCollateral[_user][_locker][_basis] = CollateralLock(
    //             cl.amount - _amount,
    //             cl.lockExpiry
    //         );
    //     }
    //     unallocatedCollateral[_user][_basis] += _amount;
    // }

    // /************************************************
    //  *  Collateral Allocation & Reallocation
    //  ***********************************************/

    // /**
    //     @notice Function to lock the amount corresponding to particleMass.
    //     @dev We expect particleMass to be relatively small, so this function checks if
    //     the user has enough funds in the unallocated pool.
    //     @param _user address of user to lock particleMass for
    //     @param _basis the address of the ERC20 token used to collateralise the given strategy
    //     @param _particleMass the amount of the ERC20 token to lock
    // */
    // function chargeParticleMass(
    //     address _user,
    //     address _basis,
    //     uint256 _particleMass
    // ) public isTFM {
    //     require(unallocatedCollateral[_user][_basis] >= _particleMass, "C13");

    //     relocateUnallocatedCollateral(
    //         _user,
    //         TreasuryAddress,
    //         _particleMass,
    //         _basis
    //     );
    // }

    // /**
    //     @notice Function to allocate collateral from a user's unallocated collateral to a strategy id
    //     @param _toStrategyID strategy id where the collateral is being allocated
    //     @param _amount amount to allocate
    // */
    // function allocateCollateral(
    //     uint256 _toStrategyID,
    //     uint256 _amount
    // ) external {
    //     address basis = (TFM(TFMAddress).getStrategy(_toStrategyID)).basis;
    //     _allocateCollateralUser(msg.sender, _toStrategyID, _amount, basis);

    //     emit AllocatedCollateral(msg.sender, _toStrategyID, _amount, basis);
    // }

    // /**
    //     @dev Function to perform collateral allocation from unallocated collateral w/o
    //     checking requirements.
    //     @param _user address of user to allocate collateral for
    //     @param _toStrategyID ID of strategy to allocate collateral to
    //     @param _amount amount of ERC20 token to allocate
    //     @param _basis address of ERC20 token used to collateralise
    // */
    // function _allocateCollateralUser(
    //     address _user,
    //     uint256 _toStrategyID,
    //     uint256 _amount,
    //     address _basis
    // ) private {
    //     require(
    //         _basis != address(0),
    //         "S2" // strategy should exist
    //     );
    //     return
    //         _reallocateNoCollateralCheck(
    //             _user,
    //             0,
    //             _toStrategyID,
    //             _amount,
    //             _basis
    //         );
    // }

    // /**
    //     @notice Function called by TFM to reallocate collateral from a strategy to another strategy
    //     or to the unallocated pool.
    //     @dev Diagram illustrating a relocation:

    //        +--------------+
    //       /|             /|
    //      / |            / |
    //     *--+-----------*  |
    //     |  |   User    |  |       Amount X      Amount X-Y
    //     |  | Personal  |  |    ===============≠≠≠≠≠≠≠≠≠≠≠≠≠>     Strategy 1
    //     |  +---Pool----+--+                  ||
    //     | /            | /                   ||
    //     |/             |/                    || Amount Y
    //     *--------------*                     |=============>     Strategy 2

    //     @param _req ReallocateCollateralRequest struct made up of:
    //     * address sender - msg.sender of original tx to TFM
    //     * address alpha - alpha of fromStrategy (used in req collat calculations)
    //     * address omega - omega of fromStrategy
    //     * uint256 alphaCollateralRequirement - from web2 collateral params
    //     * uint256 omegaCollateralRequirement - from web2 collateral params
    //     * uint256 fromStrategyID - id of strategy to reallocate collateral from
    //     (cannot be 0, use allocateCollateral to allocate from unallocated)
    //     * uint256 toStrategyID - id of strategy to reallocate collateral to
    //     (0 for deallocating to unallocated)
    //     * uint256 amount - amount to reallocate between strategies
    //     * address basis - basis of both strategies
    //     (see Types.sol for full definition).
    // */
    // function reallocateCollateral(
    //     ReallocateCollateralRequest memory _req
    // ) external isTFM {
    //     // Calculating collateral requirement for the sender
    //     //slither-disable-next-line uninitialized-local
    //     uint256 requiredCollateral;

    //     // Add strategy collateral requirement
    //     //if both side of strategy are same
    //     if (_req.sender == _req.alpha && _req.sender == _req.omega)
    //         requiredCollateral = Utils.max(
    //             _req.alphaCollateralRequirement,
    //             _req.omegaCollateralRequirement
    //         );
    //     else if (_req.sender == _req.alpha)
    //         requiredCollateral = _req.alphaCollateralRequirement;
    //     else if (_req.sender == _req.omega)
    //         requiredCollateral = _req.omegaCollateralRequirement;

    //     require(
    //         allocatedCollateral[_req.sender][_req.fromStrategyID] >=
    //             requiredCollateral + _req.amount,
    //         "C2" // "reallocation drops collateral below requirement (includes premium)"
    //     );

    //     _reallocateNoCollateralCheck(
    //         _req.sender,
    //         _req.fromStrategyID,
    //         _req.toStrategyID,
    //         _req.amount,
    //         _req.basis
    //     );
    // }

    // /**
    //     @notice Function called by TFM to lock up any collateral / premium / particleMass for a strategy.
    //     @dev See TFM.sol `spearmint` for more info.
    //     @param _req CollateralLockInitRequest struct made up of:
    //     * uint256 strategyID - id of strategy
    //     * uint256 particleMass - strategy action particleMass field
    //     * address alpha - alpha of strategy
    //     * address omega - omega of strategy
    //     * int256 premium - strategy mint premium
    //     * uint256 alphaCollateralRequirement - from web2 collateral params
    //     * uint256 omegaCollateralRequirement - from web2 collateral params
    //     * address basis - basis of strategy
    //     * address initiator - initiator of minting / transfer strategy
    //     * address targetAlpha - strategy action targetAlpha field
    //     * uint256 alphaCollateralRequirement - from web2 collateral params
    //     * uint256 omegaCollateralRequirement - from web2 collateral params
    //     * address basis - basis of strategy being claimed/transferd

    //     (see Types.sol for full definition).

    // // same fee charged to each

    //         if (_req.premium < 0)
    //             //slither-disable-next-line reentrancy-eth
    //             relocateUnallocatedCollateral(
    //                 _req.sender1,
    //                 _req.sender2,
    //                 _req.premium.abs(),
    //                 _req.basis
    //             );
    //         else if (_req.premium > 0) {
    //             //slither-disable-next-line reentrancy-eth
    //             relocateUnallocatedCollateral(
    //                 _req.sender2,
    //                 _req.sender1,
    //                 uint256(_req.premium),
    //                 _req.basis
    //             );
    //         }

    // // function relocateUnallocatedCollateral(
    // //     address _fromUser,
    // //     address _toUser,
    // //     uint256 _amount,
    // //     address _basis
    // // ) private {
    // //     if (_fromUser != _toUser) {
    // //         require(unallocatedCollateral[_fromUser][_basis] >= _amount, "C43"); //Not enough unallocated collateral to relocate

    // //         address payable fromPool = _getOrCreatePersonalPool(_fromUser);
    // //         address toPool = address(_getOrCreatePersonalPool(_toUser));
    // //         // slither-disable-next-line reentrancy-no-eth
    // //         PersonalPool(fromPool).approve(_basis, _amount);
    // //         unchecked{
    // //             unallocatedCollateral[_fromUser][_basis] -= _amount;
    // //         }
    // //         unallocatedCollateral[_toUser][_basis] += _amount;
    // //         //slither-disable-next-line arbitrary-send-erc20
    // //         IERC20(_basis).safeTransferFrom(fromPool, toPool, _amount);
    // //     }
    // // }

    // /**
    //     @notice Function to allocate sufficient collateral to a given strategy to cover the
    //     required collateral.
    //     @dev This function takes into account any collateral already allocated to a given strategy
    //     and only allocates any remaning difference from the unallocated pool.
    //     @param _user address of user to allocate collateral for
    //     @param _strategyID the ID of the strategy to allocate collateral to
    //     @param _requiredCollateral the amount of collateral required (without fees+premium)
    //     @param _basis the address of the ERC20 token to be used as collateral
    // */

    // // pass new requirement
    // // if enough

    // function _autoCollateraliseStrategy(
    //     address _user,
    //     uint256 _strategyID,
    //     uint256 _requiredCollateral,
    //     address _basis
    // ) internal {
    //     uint256 allocatedCollateral = allocatedCollateral[_user][_strategyID];
    //     // Reallocate collateral if we need more collateral than exist
    //     if (allocatedCollateral < _requiredCollateral) {
    //         unchecked {
    //             _reallocateNoCollateralCheck(
    //                 _user,
    //                 0,
    //                 _strategyID,
    //                 //reallocate only different between what _user needs and what _user has
    //                 _requiredCollateral - allocatedCollateral,
    //                 _basis
    //             );
    //         }
    //     }
    // }

    // /**
    //     @notice Function to facilitate a combination of two stratgies, by allocating
    //     the collateral of both parties from target strategy to the combined strategy.
    //     @param _req is the request to combineExecute. It is a struct that contains the following in this order:
    //     -address alpha
    //     -address omega
    //     -uint256 thisStrategyID
    //     -uint256 targetStrategyID
    //     -uint256 particleMass
    //     -address basis
    //     -bool strategiesCancelOut
    // */
    // function combineExecute(CombineRequest memory _req) external isTFM {
    //     // charge particle mass for alpha.
    //     //slither-disable-next-line reentrancy-benign,reentrancy-eth
    //     chargeParticleMass(_req.alpha, _req.basis, _req.particleMass);

    //     // charge particle mass for omega.
    //     //slither-disable-next-line reentrancy-benign,reentrancy-eth
    //     chargeParticleMass(_req.omega, _req.basis, _req.particleMass);

    //     // Move all allocated collateral of both parties to thisStrategy as targetStrategy will be removed.
    //     reallocateAllNoCollateralCheck(
    //         _req.alpha,
    //         _req.targetStrategyID,
    //         _req.thisStrategyID,
    //         _req.basis
    //     );
    //     reallocateAllNoCollateralCheck(
    //         _req.omega,
    //         _req.targetStrategyID,
    //         _req.thisStrategyID,
    //         _req.basis
    //     );
    //     //if strategy will be annihilated
    //     if (_req.strategiesCancelOut) {
    //         //it means that thisStrategy will be deleted too,
    //         //so, move allocated collateral to unallocated collateral for both sides of thisStrategy
    //         reallocateAllNoCollateralCheck(
    //             _req.alpha,
    //             _req.thisStrategyID,
    //             0, //deallocate
    //             _req.basis
    //         );
    //         reallocateAllNoCollateralCheck(
    //             _req.omega,
    //             _req.thisStrategyID,
    //             0, //deallocate
    //             _req.basis
    //         );
    //     }
    // }

    // /**
    //     @notice Function used to move some amout of allocated collateral from _fromUser user to _toUser user (more
    //     @notice precisely, move fund from user _fromUser's personal pool into _toUser's personal pool)
    //     @dev Diagram illustrating a relocation:

    //        +--------------+
    //       /|             /|
    //      / |            / |
    //     *--+-----------*  |
    //     |  |  User 1   |  |               Amount X
    //     |  | Personal  |  |    ≠≠≠≠≠≠≠≠≠≠≠≠≠≠==============>     Strategy
    //     |  +---Pool----+--+                  || Amount X+Y
    //     | /            | /                   ||
    //     |/             |/                    ||
    //     *--------------*                     ||
    //                                          ||
    //        +--------------+                  || Amount Y
    //       /|             /|                  ||
    //      / |            / |                  ||
    //     *--+-----------*  |                  ||
    //     |  |  User 2   |  |                  ||
    //     |  | Personal  |  |   ================|
    //     |  +---Pool----+--+
    //     | /            | /
    //     |/             |/
    //     *--------------*

    //     @param _fromUser user whose allocated funds are being decreased
    //     @param _toUser user whose allocated funds are being increase
    //     @param _strategyID strategy to which collateral is allocated
    //     @param _amount amount being relocated
    //     @param _basis basis of collateral being relocated
    // */
    // function relocateCollateral(
    //     address _fromUser,
    //     address _toUser,
    //     uint256 _strategyID,
    //     uint256 _amount,
    //     ///@custom:security non-reentrant
    //     address _basis
    // ) public isTFM {
    //     require(allocatedCollateral[_fromUser][_strategyID] >= _amount, "C16");

    //     address payable fromPool = _getOrCreatePersonalPool(_fromUser);
    //     address toPool = _getOrCreatePersonalPool(_toUser);
    //     //as all funds are moved accross same strategy -> it means that basis are same
    //     unchecked{
    //         allocatedCollateral[_fromUser][_strategyID] -= _amount;
    //     }
    //     allocatedCollateral[_toUser][_strategyID] += _amount;

    //     PersonalPool(fromPool).approve(_basis, _amount);
    //     //slither-disable-next-line arbitrary-send-erc20
    //     IERC20(_basis).safeTransferFrom(fromPool, toPool, _amount);
    // }

    // /**
    //     @notice Function used to move some amount of unallocated collateral from user _fromUser personal pool to user
    //     @notice _toUser personal pool
    //     @param _fromUser user whose unallocated funds are being decreased
    //     @param _toUser user whose unallocated funds are being increased
    //     @param _amount amount being relocated
    //     @param _basis basis of collateral being relocated
    // */
    // function relocateUnallocatedCollateral(
    //     address _fromUser,
    //     address _toUser,
    //     uint256 _amount,
    //     address _basis
    // ) private {
    //     if (_fromUser != _toUser) {
    //         require(unallocatedCollateral[_fromUser][_basis] >= _amount, "C43"); //Not enough unallocated collateral to relocate

    //         address payable fromPool = _getOrCreatePersonalPool(_fromUser);
    //         address toPool = address(_getOrCreatePersonalPool(_toUser));
    //         // slither-disable-next-line reentrancy-no-eth
    //         PersonalPool(fromPool).approve(_basis, _amount);
    //         unchecked{
    //             unallocatedCollateral[_fromUser][_basis] -= _amount;
    //         }
    //         unallocatedCollateral[_toUser][_basis] += _amount;
    //         //slither-disable-next-line arbitrary-send-erc20
    //         IERC20(_basis).safeTransferFrom(fromPool, toPool, _amount);
    //     }
    // }

    // /**
    //     @notice Function to reallocate a given amount of collateral without running checks on whether
    //     collateral requirements are met after reallocation.
    //     @param _user user to reallocate collateral of
    //     @param _fromStrategyID id of strategy to reallocate from
    //     @param _toStrategyID id of strategy to reallocate to
    //     @param _amount amount of allocated collateral to reallocate
    //     @param _basis basis of strategies
    // */
    // function _reallocateNoCollateralCheck(
    //     address _user,
    //     uint256 _fromStrategyID,
    //     uint256 _toStrategyID,
    //     uint256 _amount,
    //     address _basis
    // ) internal {
    //     if (_fromStrategyID == 0) {
    //         require(unallocatedCollateral[_user][_basis] >= _amount, "C11");
    //         // from unallocated to allocated
    //         unchecked {
    //             unallocatedCollateral[_user][_basis] -= _amount;
    //         }
    //         allocatedCollateral[_user][_toStrategyID] += _amount;
    //     } else {
    //         require(allocatedCollateral[_user][_fromStrategyID] >= _amount, "C46");
    //         if (_toStrategyID == 0) {
    //                unchecked {
    //                 allocatedCollateral[_user][_fromStrategyID] -= _amount;
    //             }
    //             unallocatedCollateral[_user][_basis] += _amount;
    //         } else {
    //             unchecked {
    //                 allocatedCollateral[_user][_fromStrategyID] -= _amount;
    //             }
    //             allocatedCollateral[_user][_toStrategyID] += _amount;
    //         }
    //     }
    // }

    // /**
    //     @notice Function to reallocate a portion (numerator/denominator) of collateral without running checks
    //     on whether collateral requirements are met after reallocation.
    //     @param _user user to reallocate collateral of
    //     @param _fromStrategyID id of strategy to reallocate from
    //     @param _toStrategyID id of strategy to reallocate to
    //     @param _nominator numerator of fraction of total allocated amount to reallocate
    //     @param _denominator denominator of fraction of total allocated amount to reallocate
    //     @param _basis basis of strategies
    // */
    // function reallocatePortionNoCollateralCheck(
    //     address _user,
    //     uint256 _fromStrategyID,
    //     uint256 _toStrategyID,
    //     uint256 _nominator,
    //     uint256 _denominator,
    //     address _basis
    // ) external isTFM {
    //     _reallocateNoCollateralCheck(
    //         _user,
    //         _fromStrategyID,
    //         _toStrategyID,
    //         //we didn't check that _nominator <= _denominator because of
    //         //1) it checked in TFM and
    //         //2) otherwise it will fail inside _reallocateNoCollateralCheck which has check about enough funds to
    //         //   reallocate
    //         (allocatedCollateral[_user][_fromStrategyID] * _nominator) /
    //             _denominator,
    //         _basis
    //     );
    // }

    // /**
    //     @notice Function to reallocate all collateral allocated to a strategy collateral without
    //     running checks on whether collateral requirements are met after reallocation.
    //     @param _user user to reallocate collateral of
    //     @param _fromStrategyID id of strategy to reallocate from
    //     @param _toStrategyID id of strategy to reallocate to
    //     @param _basis basis of strategies
    // */
    // function reallocateAllNoCollateralCheck(
    //     address _user,
    //     uint256 _fromStrategyID,
    //     uint256 _toStrategyID,
    //     address _basis
    // ) public isTFM {
    //     _reallocateNoCollateralCheck(
    //         _user,
    //         _fromStrategyID,
    //         _toStrategyID,
    //         allocatedCollateral[_user][_fromStrategyID],
    //         _basis
    //     );
    // }

    // /**
    //     @notice Function called by TFM to mint a strategy for two parties by a third-party
    //     taking neither side of the strategy.
    //     @dev See TFM.sol `peppermint` function for more info.
    //     @param _req PeppermintRequest struct made up of:
    //     * address sender - msg.sender of original tx to TFM
    //     * uint256 strategyID - id of strategy newly minted strategy
    //     * address alpha - alpha of new strategy
    //     * address omega - omega of new strategy
    //     * uint256 alphaCollateralRequirement - from web2 collateral params
    //     * uint256 omegaCollateralRequirement - from web2 collateral params
    //     * address basis - basis of new strategy
    //     * int256 premium - strategy mint premium
    //     * uint256 particleMass - strategy action particleMass field
    //     (see Types.sol for full definition)
    // */
    // function peppermintExecute(PeppermintRequest memory _req) external isTFM {
    //     // Compute collateral required + premium per side.
    //     //  If premium < 0: _omega is to pay premium to _alpha.
    //     //  If premium > 0: _alpha is to pay premium to _omega.
    //     uint256 unsignedPremium = _req.premium < 0
    //         ? uint256(-_req.premium)
    //         : uint256(_req.premium);
    //     uint256 premiumAlpha = (_req.premium < 0 ? unsignedPremium : 0);
    //     uint256 alphaCollateralRequirement = _req.alphaCollateralRequired +
    //         premiumAlpha +
    //         _req.particleMass;
    //     uint256 premiumOmega = (_req.premium > 0 ? unsignedPremium : 0);
    //     uint256 omegaCollateralRequirement = _req.omegaCollateralRequired +
    //         premiumOmega +
    //         _req.particleMass;
    //     // Attempt to unlock the required collateral by both parties.
    //     _unlockCollateral(
    //         _req.sender,
    //         _req.alpha,
    //         _req.sender,
    //         _req.basis,
    //         alphaCollateralRequirement
    //     );
    //     _unlockCollateral(
    //         _req.sender,
    //         _req.omega,
    //         _req.sender,
    //         _req.basis,
    //         omegaCollateralRequirement
    //     );

    //     // Collateralise newly minted strategy for both parties, covering any collateral and premium required.
    //     _autoCollateraliseStrategy(
    //         _req.alpha,
    //         _req.strategyID,
    //         _req.alphaCollateralRequired,
    //         _req.basis
    //     );
    //     _autoCollateraliseStrategy(
    //         _req.omega,
    //         _req.strategyID,
    //         _req.omegaCollateralRequired,
    //         _req.basis
    //     );

    //     // Transfer premium according to the inputs.
    //     if (_req.premium < 0)
    //         //slither-disable-next-line reentrancy-eth
    //         relocateUnallocatedCollateral(
    //             _req.alpha,
    //             _req.omega,
    //             unsignedPremium,
    //             _req.basis
    //         );
    //         //slither-disable-next-line reentrancy-eth
    //     else
    //         relocateUnallocatedCollateral(
    //             _req.omega,
    //             _req.alpha,
    //             unsignedPremium,
    //             _req.basis
    //         );
    //     //charge particle mass and send it to TreasuryAddress
    //     relocateUnallocatedCollateral(
    //         _req.alpha,
    //         TreasuryAddress,
    //         _req.particleMass,
    //         _req.basis
    //     );
    //     //charge particle mass and send it to TreasuryAddress
    //     relocateUnallocatedCollateral(
    //         _req.omega,
    //         TreasuryAddress,
    //         _req.particleMass,
    //         _req.basis
    //     );
    // }

    // // If any operation apart from mint, they will have a personal pool already

    // /**
    //     @notice get address of wrapped native coin
    //     @return address of wrapped native coint
    // */
    // function getWrappedNativeCoin() external view returns (IWrappedNativeCoin) {
    //     return wrappedNativeCoin;
    // }

    // function _getOrCreatePersonalPool(
    //     address _user
    // ) internal returns (address payable) {
    //     address payable personalPool = personalPools[_user];
    //     if (personalPool == address(0)) {
    //         personalPool = payable(new PersonalPool());
    //         personalPools[_user] = personalPool;
    //     }
    //     return personalPool;
    // }
}
