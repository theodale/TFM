// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../misc/Types.sol";
import {Utils} from "../libraries/Utils.sol";
import {TFMStorage} from "./TFMStorage.sol";
import {CollateralManager} from "./CollateralManager.sol";
import {ITFM} from "../interfaces/ITFM.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "hardhat/console.sol";

contract TFM is
    TFMStorage,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ITFM
{
    // *** LIBRARIES ***

    using Utils for int256;
    using Utils for int256[2][];

    // *** STATE VARIABLES ***

    // Signs and validates data packages
    address trufinOracle;
    // Used to ensure only recent data packages are valid => updated periodically
    uint256 oracleNonce;
    // Time at which the oracle nonce was last updated
    uint256 latestOracleNonceUpdateTime;
    // Contract will lock itself if the oracle nonce has not been updated in the last `lockTime` seconds
    uint256 lockTime;

    // Prevents replay attacks using spearminter signatures
    mapping(address => mapping(address => uint256)) internal mintNonce;

    // *** INITIALIZE ***

    function initialize(
        address _collateralManager,
        address _owner,
        address _liquidator,
        address _trufinOracle
    ) external initializer {
        // Emit initialization event first so TFM entity created on subgraph before its ownership is edited
        emit Initialization();

        // Initialize parent state
        __ReentrancyGuard_init();
        __Ownable_init();
        transferOwnership(_owner);

        // Set relevant addresses & contracts
        liquidator = _liquidator;
        collateralManager = CollateralManager(_collateralManager);
        trufinOracle = _trufinOracle;
    }

    // *** GETTERS ***

    // Returns the mint nonce of a pair of users
    function getMintNonce(
        address partyOne,
        address partyTwo
    ) public view returns (uint256) {
        if (partyOne < partyTwo) {
            return mintNonce[partyOne][partyTwo];
        } else {
            return mintNonce[partyTwo][partyOne];
        }
    }

    // Read a strategy with a certain ID
    function getStrategy(
        uint256 _strategyID
    ) external view returns (Strategy memory) {
        return strategies[_strategyID];
    }

    // *** SETTERS ***

    // Admim method to set new liquidator address
    function setLiquidatorAddress(address _liquidator) public onlyOwner {
        liquidator = _liquidator;
    }

    // Admin method to set new collateral manager address
    function setCollateralManagerAddress(
        address _collateralManager
    ) external onlyOwner {
        collateralManager = CollateralManager(_collateralManager);
    }

    // *** ACTIONS ***

    // Thoughts
    // - change argument structs?
    // - make single call to utils?
    function spearmint(
        SpearmintDataPackage calldata _spearmintDataPackage,
        SpearmintParameters calldata _spearmintParameters,
        bytes calldata alphaSignature,
        bytes calldata omegaSignature
    ) external {
        Utils.checkSpearminterSignatures(
            _spearmintParameters,
            alphaSignature,
            omegaSignature,
            getMintNonce(_spearmintParameters.alpha, _spearmintParameters.omega)
        );

        // _checkOracleNonce(_spearmintDataPackage.oracleNonce);

        Utils.checkSpearmintDataPackage(
            _spearmintDataPackage,
            _spearmintParameters.trufinOracleSignature,
            trufinOracle
        );

        uint256 strategyId = _createStrategy(
            _spearmintDataPackage,
            _spearmintParameters
        );

        collateralManager.executeSpearmint(
            strategyId,
            _spearmintParameters.alpha,
            _spearmintParameters.omega,
            _spearmintDataPackage.basis,
            _spearmintDataPackage.alphaCollateralRequirement,
            _spearmintDataPackage.omegaCollateralRequirement,
            _spearmintDataPackage.alphaFee,
            _spearmintDataPackage.omegaFee,
            _spearmintParameters.premium
        );

        // _incrementMintNonce(
        //     _spearmintParameters.alpha,
        //     _spearmintParameters.omega
        // );

        // emit Spearmint(strategyId);
    }

    // *** INTERNAL METHODS ***

    // Creates a new strategy and returns its ID
    function _createStrategy(
        SpearmintDataPackage calldata _spearmintDataPackage,
        SpearmintParameters calldata _spearmintParameters
    ) internal returns (uint256) {
        uint256 newStrategyId = strategyCounter++;

        strategies[newStrategyId] = Strategy(
            _spearmintParameters.transferable,
            _spearmintDataPackage.bra,
            _spearmintDataPackage.ket,
            _spearmintDataPackage.basis,
            _spearmintParameters.alpha,
            _spearmintParameters.omega,
            _spearmintDataPackage.expiry,
            _spearmintDataPackage.amplitude,
            _spearmintDataPackage.phase
        );

        return newStrategyId;
    }

    // Internal method that updates a pairs mint nonce
    function _incrementMintNonce(address partyOne, address partyTwo) internal {
        if (partyOne < partyTwo) {
            mintNonce[partyOne][partyTwo]++;
        } else {
            mintNonce[partyTwo][partyOne]++;
        }
    }

    // Performs oracle nonce-related checks
    function _checkOracleNonce(uint256 _oracleNonce) internal view {
        // Check whether input nonce is outdated
        require(
            (_oracleNonce >= _oracleNonce) &&
                (_oracleNonce - _oracleNonce <= 1),
            "TFM: Oracle nonce has expired"
        );

        // Check whether contract is locked due to oracle nonce not being updated
        require(
            (block.timestamp < latestOracleNonceUpdateTime + lockTime),
            "TFM: Contract locked due as oracle nonce has not been updated"
        );
    }

    // Upgrade authorization
    function _authorizeUpgrade(address) internal override onlyOwner {}

    // /************************************************
    //  *  Collateral Management
    //  ***********************************************/

    // /**
    //     @notice Function to reallocate collateral from a strategy to another strategy or to the unallocated pool.
    //     @dev This function verifies that both collateral requirements and premium requirements are not violated by reallocation
    //     (i.e.: that fromStrategy is sufficiently collateralised after the reallocation and that any posted premium pending withdrawal is retained).
    //     Whereas, the actual reallocation happens through the Collateral Manager.
    //     Note basis will be inferred from _paramsID.strategyID
    //     @param _toStrategyID ID of strategy to move collateral to (note if this is 0, we move collateral to the unallocated pool)
    //     @param _amount amount of collateral to move
    //     @param _paramsID struct containing the parameters (strategyID to move collateral from, collateral requirements, ora_oracleNonce)
    //     @param _signature web2 signature of hashed message
    // */
    // function reallocateCollateral(
    //     uint256 _toStrategyID,
    //     uint256 _amount,
    //     CollateralParamsID calldata _paramsID,
    //     bytes calldata _signature
    // ) external nonReentrant {
    //     //check ora_oracleNonce is valid and contract is not locked
    //     collateralManager.checkora_oracleNonce(_paramsID.ora_oracleNonce);

    //     // Verify if collateral information provided is valid and sufficiently up-to-date.
    //     // Note we use the internal helper function to read the strategy params from storage.
    //     Utils.checkCollateralRequirements(
    //         _paramsID,
    //         _signature,
    //         strategies[_paramsID.strategyID],
    //         collateralManager.ora_oracleNonce(),
    //         collateralManager.Web2Address()
    //     );

    //     Strategy storage fromStrategy = strategies[_paramsID.strategyID];
    //     address fromStrategyBasis = fromStrategy.basis;
    //     // Ensure that either rellocation is done to unallocated pool, or that the strategies share a basis.
    //     require(
    //         _toStrategyID == 0 ||
    //             fromStrategyBasis == strategies[_toStrategyID].basis,
    //         "S31" // "strategy basis must be the same"
    //     );

    //     collateralManager.reallocateCollateral(
    //         ReallocateCollateralRequest(
    //             msg.sender,
    //             fromStrategy.alpha,
    //             fromStrategy.omega,
    //             _paramsID.alphaCollateralRequirement,
    //             _paramsID.omegaCollateralRequirement,
    //             _paramsID.strategyID,
    //             _toStrategyID,
    //             _amount,
    //             fromStrategyBasis
    //         )
    //     );
    //     emit ReallocatedCollateral(
    //         _paramsID.strategyID,
    //         _toStrategyID,
    //         _amount
    //     );
    // }

    // /**
    //     @notice Function to mint a strategy for two parties by a third-party taking neither side of the strategy.
    //     This function ensures that _alpha and _omega are sufficiently collateralised to take up their side and
    //     that they have locked enough collateral to also cover any premium to be paid.
    //     In order to call this function, collateral requirements (from the Web2 backend) need to be sent.
    //     @dev This function is used by the auction house once an auction has completed, so that the
    //     filled orders can be minted. At this stage, both parties involved in the strategy to be minted
    //     must have locked enough collateral (with the auction house as the trusted locker), to cover
    //     collateral requirements and any premium to be paid. The collateral requirements must be provided
    //     by the auction initiator at the start of the auction.
    //     @param _collateralParams the parameters of the strategy to be minted (basis, expiry, amplitude, phase),
    //     the collateral requirements and the collateral nonce (the version of the web2 database used to compute reqs)
    //     @param _transferable flag to indicate if strategy is transferable w/o requiring approval
    //     @param _alpha address to take alpha side of strategy
    //     @param _omega adddress to take omega side of strategy
    //     @param _signature signature of _hashedMessage by AdminAddress
    //     @param _premium amount of premium
    //     note if +ve premium is paid by _omega to _alpha, and vice-versa if premium is -ve
    // */
    // function peppermint(
    //     CollateralParamsFull calldata _collateralParams,
    //     bool _transferable,
    //     address _alpha,
    //     address _omega,
    //     bytes calldata _signature,
    //     int256 _premium
    // ) external {
    //     // Valerii Review Comment:
    //     // _alpha and _omega are input parameters and caller can set any to pass next "require"
    //     // you should use other mechanism
    //     // Matyas Review Respons:
    //     // Again this is fine here as _alpha and _omega specify which parties should share the newly minted strategy.
    //     // Additionally, this call will only succeed if _alpha and _omega have both set the caller as a trusted locker
    //     // and have locked enough collateral to cover the collateral requirements + premium, to the caller.

    //     require((msg.sender != _alpha) && (msg.sender != _omega), "A22"); // "alpha and omega must not be msg.sender when pepperminting"

    //     // Verify if collateral information provided is valid and sufficiently up-to-date.
    //     // Note here we call the Collateral Manager directly as we have all strategy params specified in _params.
    //     _checkAndCreateStrategy(
    //         _collateralParams,
    //         _signature,
    //         _alpha,
    //         _omega,
    //         _transferable
    //     );

    //     collateralManager.peppermintExecute(
    //         PeppermintRequest(
    //             msg.sender,
    //             strategyCounter,
    //             _alpha,
    //             _omega,
    //             _collateralParams.alphaCollateralRequirement,
    //             _collateralParams.omegaCollateralRequirement,
    //             _collateralParams.basis,
    //             _premium,
    //             getParticleMass(strategyCounter, ActionType.CLAIM)
    //         )
    //     );
    //     emit Pepperminted(strategyCounter);
    // }

    // /************************************************
    //  *  Actions
    //  ***********************************************/

    // /**
    //     @notice Function to annihilate an existing strategy, if msg.caller is either
    //     on both sides of a strategy, or if they are on one side and the other side has not been claimed.
    //     Note this function also deallocates any collateral allocated to the strategy by msg.caller.
    //     @param _strategyID the ID of the strategy to annihilate
    // */
    // function annihilate(uint256 _strategyID) external {
    //     Strategy storage strategy = strategies[_strategyID];
    //     address alpha = strategy.alpha;
    //     address omega = strategy.omega;
    //     require(
    //         (alpha == msg.sender && omega == msg.sender) ||
    //             (alpha == address(0) && omega == msg.sender) ||
    //             (alpha == msg.sender && omega == address(0)),
    //         "A20" // "msg.sender not authorised to annihilate strategy"
    //     );

    //     // Deallocate any collateral allocated to the strategy about to be annihilated.
    //     collateralManager.reallocateAllNoCollateralCheck(
    //         msg.sender,
    //         _strategyID,
    //         0,
    //         strategy.basis
    //     );
    //     delete strategies[_strategyID]; // Delete strategy.
    //     delete strategyNonce[_strategyID];

    //     emit Annihilated(_strategyID);
    //     emit Deleted(_strategyID);
    // }

    // /**
    //     @notice Function to update user counter by 1 in desc order of user addresses
    //     @param user1 Address of user 1
    //     @param user2 Address of user 2
    //  */
    // function updateUserCounter(address user1, address user2) private {
    //     if (user1 < user2) {
    //         userPairCounter[user1][user2]++;
    //     } else {
    //         userPairCounter[user2][user1]++;
    //     }
    // }

    // /**
    //     @notice Function for the recepient (_targetUser) of an approved transfer to finalise the transfer and gain ownership
    //     of the specified side. This function ensures that the recepient is sufficiently collateralised and has posted any required premium.
    //     @dev This function optionally transfer premium from the transfer initiator to the recepient or vice-versa if it has been specified,
    //     and deallocates any allocated collateral of the transfer initiator if successfull.
    //     @param _collateralParams struct containing the full parameters
    //     @param _params struct containing the parametere like the 3-4 party signatures and target user, premium
    // */

    // function transfer(
    //     CollateralParamsFull calldata _collateralParams,
    //     TransferParams calldata _params
    // ) external {
    //     //check ora_oracleNonce is valid and contract is not locked
    //     collateralManager.checkora_oracleNonce(_collateralParams.ora_oracleNonce);

    //     Strategy storage strategy = strategies[_params.thisStrategyID];
    //     {
    //         Utils.checkWeb2Signature(
    //             _collateralParams,
    //             strategy,
    //             _params.sigWeb2,
    //             collateralManager.ora_oracleNonce(),
    //             collateralManager.Web2Address(),
    //             false
    //         );
    //     }
    //     address alpha = strategy.alpha;
    //     address omega = strategy.omega;
    //     //check both alpha & omega have signed, return who signed first
    //     Utils.checkTransferUserSignaturesAndParams(
    //         _params,
    //         alpha,
    //         omega,
    //         strategyNonce[_params.thisStrategyID],
    //         strategy.transferable,
    //         strategy.expiry
    //     );

    //     address transferer = _params.alphaTransfer ? alpha : omega;

    //     //Increase strategyNonce
    //     strategyNonce[_params.thisStrategyID]++;

    //     // Verify if collateral information provided is valid and sufficiently up-to-date.
    //     // Note we use the internal helper function to read the strategy params from storage.
    //     //checkCollateralRequirements(_hashedMessage, _paramsID, _signature); TODO REMOVE!

    //     //  If premium < 0: msg.sender is paying _targetUser.
    //     //  If premium > 0: _targetUser is paying msg.sender.
    //     uint256 particleMass = getParticleMass(
    //         _params.thisStrategyID,
    //         ActionType.TRANSFER
    //     );

    //     address basis = strategy.basis;
    //     collateralManager.collateralMoveExecute(
    //         CollateralMoveRequest(
    //             transferer,
    //             _params.targetUser,
    //             _params.thisStrategyID,
    //             particleMass,
    //             alpha,
    //             omega,
    //             _params.premium,
    //             _collateralParams.alphaCollateralRequirement,
    //             _collateralParams.omegaCollateralRequirement,
    //             basis,
    //             _params.alphaTransfer,
    //             true
    //         )
    //     );

    //     // Deallocate initiators collateral as the transfer has been completed.
    //     if (omega != alpha) {
    //         collateralManager.reallocateAllNoCollateralCheck(
    //             transferer,
    //             _params.thisStrategyID,
    //             0,
    //             basis
    //         );
    //     }

    //     address initiator;

    //     if (_params.alphaTransfer) {
    //         initiator = strategy.alpha;
    //         strategy.alpha = _params.targetUser;
    //     } else {
    //         initiator = strategy.omega;
    //         strategy.omega = _params.targetUser;
    //     }
    //     emit Transferred(_params.thisStrategyID, initiator);
    // }

    // /**
    //     @notice Function to perform a combination of two stratgies shared between two users.
    //     @dev This action can only be performed on two stratgies where the two users are either
    //     alpha/omega on both strategies, or they are both alpha on one and omega on the other.
    //     This combination can be performed in one single step and called by anyone, as long as the signatures are correct.
    //     Note that we do not check collateral requirements here as the strategies are already shared
    //     between the same two users.
    //     @param _params is the input struct for teh function, containing:
    //         thisStrategyID the ID of one of the two strategies to combine (this strategy
    //         will be updated to represent the combination of the two)
    //         targetStrategyID the ID of the other strategy to combine with (this strategy
    //         will be deleted)
    // */
    // function combine(CombineParams calldata _params) external {
    //     //check ora_oracleNonce is valid and contract is not locked
    //     collateralManager.checkora_oracleNonce(_params.ora_oracleNonce);

    //     Strategy storage thisStrategy = strategies[_params.thisStrategyID];
    //     Strategy storage targetStrategy = strategies[_params.targetStrategyID];
    //     Utils.strategiesCompatible(
    //         _params.sigWeb2,
    //         thisStrategy,
    //         targetStrategy,
    //         _params.ora_oracleNonce,
    //         collateralManager.Web2Address()
    //     );
    //     address thisAlpha = thisStrategy.alpha;
    //     address thisOmega = thisStrategy.omega;
    //     address targetOmega = targetStrategy.omega;
    //     //check both alpha & omega have signed, return who signed first
    //     Utils.checkCombineSignatures(
    //         _params,
    //         thisAlpha,
    //         thisOmega,
    //         strategyNonce[_params.thisStrategyID],
    //         strategyNonce[_params.targetStrategyID],
    //         collateralManager.ora_oracleNonce(),
    //         targetStrategy.alpha,
    //         targetOmega
    //     );

    //     //Increase strategyNonce for remaining strategy
    //     strategyNonce[_params.thisStrategyID]++;

    //     uint256 thisParticleMass = getParticleMass(
    //         _params.thisStrategyID,
    //         ActionType.COMBINATION
    //     );
    //     uint256 targetParticleMass = getParticleMass(
    //         _params.targetStrategyID,
    //         ActionType.COMBINATION
    //     );

    //     // Combine the wavefn's representing the target strategies.
    //     DecomposedWaveFunction memory decwavefn = Utils.wavefnCombine(
    //         thisStrategy.phase,
    //         thisStrategy.amplitude,
    //         targetStrategy.phase,
    //         targetStrategy.amplitude,
    //         thisAlpha == targetOmega // Indicates whether the strategies should be "added" or "subtracted".
    //     );
    //     bool strategiesCancelOut = (decwavefn.amplitude == 0);

    //     collateralManager.combineExecute(
    //         CombineRequest(
    //             thisAlpha,
    //             thisOmega,
    //             _params.thisStrategyID,
    //             _params.targetStrategyID,
    //             // For combinations, the maximum particleMass is taken of the two strategies
    //             thisParticleMass > targetParticleMass
    //                 ? thisParticleMass
    //                 : targetParticleMass,
    //             thisStrategy.basis,
    //             strategiesCancelOut
    //         )
    //     );

    //     if (strategiesCancelOut) {
    //         //Strategies cancel out
    //         delete strategies[_params.thisStrategyID]; // Delete thisStrategy.
    //         delete strategyNonce[_params.thisStrategyID]; //Delete thisStrategy Nonce
    //         emit Deleted(_params.thisStrategyID);
    //     } else {
    //         thisStrategy.phase = decwavefn.phase;
    //         thisStrategy.amplitude = decwavefn.amplitude;
    //         thisStrategy.maxNotional = decwavefn.maxNotional;
    //     }
    //     delete strategies[_params.targetStrategyID]; // Delete tarstrategies.
    //     delete strategyNonce[_params.targetStrategyID]; //Delete tarstrategies Nonce

    //     emit Combined(_params.thisStrategyID, _params.targetStrategyID);
    //     emit Deleted(_params.targetStrategyID);
    // }

    // /**
    //     @notice Function to initiate a novation of two stratgies shared between three users,
    //     in order to decrease the overall collateral locked in the system.
    //     @dev For a novation to be possible both strategies need to have the same phase
    //     (i.e.: the same strikes) but can have different amplitudes.
    //     Novations can either be complete -if the amplitudes are the same - or partial -if the amplitudes are not the same.

    //     There are 3 scenarios to consider:

    //     Scenario 1 [Complete Novation]: the amplitude of the 2 stratgies (AB / AC) are the same
    //     In this case, we remove the strategy BC and redirect the strategy AB to be shared between AC.

    //     A          C        A --[50]-- C
    //      \        /
    //      [50]   [50]   ==>
    //       \     /
    //        \   /
    //          B                   B

    //     Scenario 2 [Partial Novation]: the amplitude of AB is more than the amplitude of BC
    //     In this case, we redirect the strategy BC to be shared between AC, and decrease the size of AB.
    //     A          C        A --[30]-- C
    //      \        /          \
    //      [70]   [30]   ==>   [40]
    //       \     /             \
    //        \   /               \
    //          B                   B

    //     Scenario 3 [Partial Novation]: the amplitude of AB is less than the amplitude of BC
    //     In this case, we redirect the strategy AB to be shared between AC, and decrease the size of BC.
    //     A          C        A --[30]-- C
    //      \        /                   /
    //      [30]   [70]   ==>          [40]
    //       \     /                   /
    //        \   /                   /
    //          B                   B

    //     The following conventions are used in the code to simplify the handling of the cases.
    //     The strategy AB is referred to as "thisStrategy" where A is required to be omega, and B to be alpha.
    //     The strategy BC is referred to as "tarstrategies" where B is required to be omega, and C to be alpha.
    //     Furthermore, we impose that the newly created strategy between AC will be transferable iff
    //     either thisStrategy or tarstrategies are transferable.
    //     Additionally, we require that the novation is initiated by B.
    //     @param _params struct containing the parameters (thisStrategyID, targetStrategyID, actionCount1, actionCount2, timestamp)
    // */
    // function novate(NovateParams calldata _params) external {
    //     //check ora_oracleNonce is valid and contract is not locked
    //     collateralManager.checkora_oracleNonce(_params.ora_oracleNonce);

    //     //  Verify that the stratgies share a basis and expiry
    //     Strategy storage thisStrategy = strategies[_params.thisStrategyID];
    //     Strategy storage targetStrategy = strategies[_params.targetStrategyID];
    //     Utils.strategiesCompatible(
    //         _params.sigWeb2,
    //         thisStrategy,
    //         targetStrategy,
    //         _params.ora_oracleNonce,
    //         collateralManager.Web2Address()
    //     );

    //     // Verify that the strategies share a phase
    //     require(
    //         Utils.wavefnEq(thisStrategy.phase, targetStrategy.phase),
    //         "S35"
    //     ); // "strategies are not compatible"

    //     address initiator;

    //     // Deal with all the cases in which novation can take place
    //     {
    //         if (
    //             (thisStrategy.amplitude < 0 && targetStrategy.amplitude < 0) ||
    //             (thisStrategy.amplitude > 0 && targetStrategy.amplitude > 0)
    //         ) {
    //             // Initiator has to be - (thisStrategy.alpha == tarstrategies.omega) || (thisStrategy.omega == tarstrategies.alpha)
    //             require(
    //                 (thisStrategy.alpha == targetStrategy.omega) ||
    //                     (thisStrategy.omega == targetStrategy.alpha),
    //                 "S36 - A"
    //             ); // Novation: Initiator invalid for when amplitude product is less than 0
    //             initiator = (thisStrategy.alpha == targetStrategy.omega)
    //                 ? thisStrategy.alpha
    //                 : thisStrategy.omega;
    //         } else if (
    //             (thisStrategy.amplitude < 0 && targetStrategy.amplitude > 0) ||
    //             (thisStrategy.amplitude > 0 && targetStrategy.amplitude < 0)
    //         ) {
    //             // Initiator has to be - (thisStrategy.alpha == tarstrategies.alpha) || (thisStrategy.omega == tarstrategies.omega)
    //             require(
    //                 (thisStrategy.alpha == targetStrategy.alpha) ||
    //                     (thisStrategy.omega == targetStrategy.omega),
    //                 "S36 - B"
    //             ); // Novation: Initiator invalid for when amplitude product is greater than 0
    //             initiator = (thisStrategy.alpha == targetStrategy.alpha)
    //                 ? thisStrategy.alpha
    //                 : targetStrategy.omega;
    //         } else {
    //             revert("S37");
    //         }
    //     }

    //     // Verify Params
    //     Utils.checkNovationSignatures(
    //         _params,
    //         thisStrategy,
    //         targetStrategy,
    //         initiator,
    //         strategyNonce[_params.thisStrategyID],
    //         strategyNonce[_params.targetStrategyID],
    //         collateralManager.ora_oracleNonce()
    //     );

    //     uint256 thisParticleMass = getParticleMass(
    //         _params.thisStrategyID,
    //         ActionType.NOVATION
    //     );
    //     uint256 targetParticleMass = getParticleMass(
    //         _params.targetStrategyID,
    //         ActionType.NOVATION
    //     );

    //     // calculate particle mass aka fees
    //     uint256 particleMass = thisParticleMass > targetParticleMass
    //         ? thisParticleMass
    //         : targetParticleMass;
    //     // Deduct particle mass aka fees
    //     collateralManager.chargeParticleMass(
    //         initiator,
    //         thisStrategy.basis,
    //         particleMass
    //     );

    //     novateFinalise(
    //         _params.thisStrategyID,
    //         _params.targetStrategyID,
    //         initiator
    //     );

    //     emit Novated(_params.thisStrategyID, _params.targetStrategyID);
    // }

    // /**
    //  * @notice finalise novation
    //  * @param _thisStrategyID what strategies to novate
    //  * @param _targetStrategyID what strategies to novate
    //  * @param _initiator who is initiator
    //  */
    // function novateFinalise(
    //     uint256 _thisStrategyID,
    //     uint256 _targetStrategyID,
    //     address _initiator
    // ) private {
    //     Strategy storage thisStrategy = strategies[_thisStrategyID];
    //     Strategy storage targetStrategy = strategies[_targetStrategyID];

    //     // Update strategy nonces
    //     {
    //         strategyNonce[_thisStrategyID]++;
    //         strategyNonce[_targetStrategyID]++;
    //     }

    //     uint256 thisAmplitude = ((thisStrategy.amplitude).abs());
    //     uint256 targetAmplitude = ((targetStrategy.amplitude).abs());
    //     address thisStrategyAlpha = thisStrategy.alpha;
    //     address targetStrategyAlpha = targetStrategy.alpha;
    //     address thisStrategyOmega = thisStrategy.omega;
    //     address targetStrategyOmega = targetStrategy.omega;

    //     bool newTransferable = thisStrategy.transferable ||
    //         targetStrategy.transferable;

    //     if (thisAmplitude < targetAmplitude) {
    //         // Scenario 3 - redirect (alpha) AB to be AC + decrease BC.
    //         // Relocate portion of collateral for decreased BC to newly created AC.
    //         collateralManager.reallocatePortionNoCollateralCheck(
    //             (_initiator == targetStrategyAlpha)
    //                 ? targetStrategyOmega
    //                 : targetStrategyAlpha, // Corresponds to person who is not the initiator in tarstrategies
    //             _targetStrategyID,
    //             _thisStrategyID,
    //             thisAmplitude,
    //             targetAmplitude,
    //             thisStrategy.basis
    //         );
    //         // Dellocate initiator's collateral from thisStrategy.
    //         collateralManager.reallocateAllNoCollateralCheck(
    //             _initiator, // Corresponds to B.
    //             _thisStrategyID, // Corresponds to AC.
    //             0,
    //             thisStrategy.basis
    //         );

    //         // Update the params of the strategies.
    //         thisStrategy.transferable = newTransferable;
    //         if (_initiator == thisStrategyAlpha) {
    //             thisStrategy.alpha = (_initiator == targetStrategyAlpha)
    //                 ? targetStrategyOmega
    //                 : targetStrategyAlpha;
    //         } else {
    //             thisStrategy.omega = (_initiator == targetStrategyAlpha)
    //                 ? targetStrategyOmega
    //                 : targetStrategyAlpha;
    //         }

    //         targetAmplitude = targetAmplitude - thisAmplitude;
    //         targetStrategy.amplitude = (targetStrategy.amplitude < 0)
    //             ? -int256(targetAmplitude)
    //             : int256(targetAmplitude);
    //     } else if (thisAmplitude > targetAmplitude) {
    //         // Scenario 2 - redirect (omega) BC to be AC + decrease AB
    //         // Rellocate portion of collateral for decreased AB to newly created AC.
    //         collateralManager.reallocatePortionNoCollateralCheck(
    //             (_initiator == thisStrategyOmega)
    //                 ? thisStrategyAlpha
    //                 : thisStrategyOmega, // Corresponds to A.
    //             _thisStrategyID, // Corresponds to AB.
    //             _targetStrategyID, // Corresponds to AC.
    //             (targetAmplitude),
    //             (thisAmplitude),
    //             thisStrategy.basis
    //         );
    //         // Dellocate B's collateral from redirected BC.
    //         collateralManager.reallocateAllNoCollateralCheck(
    //             _initiator, // Corresponds to B.
    //             _targetStrategyID, // Corresponds to AC.
    //             0,
    //             thisStrategy.basis
    //         );

    //         // Update the params of the strategies.
    //         targetStrategy.transferable = newTransferable;
    //         if (_initiator == targetStrategyOmega) {
    //             targetStrategy.omega = (_initiator == thisStrategyOmega)
    //                 ? thisStrategyAlpha
    //                 : thisStrategyOmega;
    //         } else {
    //             targetStrategy.alpha = (_initiator == thisStrategyOmega)
    //                 ? thisStrategyAlpha
    //                 : thisStrategyOmega;
    //         }

    //         thisAmplitude = (thisAmplitude - targetAmplitude);
    //         thisStrategy.amplitude = (thisStrategy.amplitude < 0)
    //             ? -int256(thisAmplitude)
    //             : int256(thisAmplitude);
    //     } else if (thisAmplitude == targetAmplitude) {
    //         // Scenario 1 - redirect (alpha) AB to be AC + delete BC.
    //         // Deallocated B's collateral from both strategies.
    //         collateralManager.reallocateAllNoCollateralCheck(
    //             _initiator, // Corresponds to B.
    //             _thisStrategyID, // Corresponds to AC.
    //             0,
    //             thisStrategy.basis
    //         );
    //         collateralManager.reallocateAllNoCollateralCheck(
    //             _initiator, // Corresponds to B.
    //             _targetStrategyID, // Corresponds to deleted strategy.
    //             0,
    //             thisStrategy.basis
    //         );

    //         // Reallocate C's collateral to AC.
    //         collateralManager.reallocateAllNoCollateralCheck(
    //             (_initiator == targetStrategyAlpha)
    //                 ? targetStrategyOmega
    //                 : targetStrategyAlpha, // Corresponds to C.
    //             _targetStrategyID, // Corresponds to deleted strategy.
    //             _thisStrategyID, // Corresponds to AC.
    //             thisStrategy.basis
    //         );

    //         // Update the params of the strategies.
    //         thisStrategy.transferable = newTransferable;
    //         if (_initiator == thisStrategyAlpha) {
    //             thisStrategy.alpha = (_initiator == targetStrategyOmega)
    //                 ? targetStrategyAlpha
    //                 : targetStrategyOmega;
    //         } else {
    //             thisStrategy.omega = (_initiator == targetStrategyOmega)
    //                 ? targetStrategyAlpha
    //                 : targetStrategyOmega;
    //         }
    //         delete strategies[_targetStrategyID]; // Delete original BC strategy.
    //         delete strategyNonce[_targetStrategyID]; // Delete strategyNonce for strategy BC
    //         emit Deleted(_targetStrategyID);
    //     }
    // }

    // /************************************************
    //  *  Option Functionality
    //  ***********************************************/

    // /**
    //     @notice Function to exercise an expired option.
    //     @dev Once a strategy has expired the Web2 backend will return alpha and omega payout
    //     instead of collateral requirements, however, the struct is reused to avoid redundancy.
    //     To ensure that the sent collateral information is correct (containing payouts instead of collateral requirements),
    //     we require that the collateral nonce in the data corresponds to the most recent version
    //     (instead of allowing collateral information from the previous checkpoint as with regular collateral information).
    //     Note that any gains are paid out as soon as the first party calls exercise, however, the strategy is only
    //     deleted once both parties have exercised for better UX.
    //     @param _paramsID struct containing the parameters (strategyID, collateral requirements, ora_oracleNonce)
    //     @param _signature web2 signature of hashed message
    // */
    // function exercise(
    //     CollateralParamsID calldata _paramsID,
    //     bytes calldata _signature
    // ) external {
    //     //check ora_oracleNonce is valid and contract is not locked
    //     collateralManager.checkora_oracleNonce(_paramsID.ora_oracleNonce);
    //     //here we require equility of internal and external nonces
    //     require(collateralManager.ora_oracleNonce() == _paramsID.ora_oracleNonce, "C3");

    //     uint256 strategyID = _paramsID.strategyID;
    //     Strategy storage strategy = strategies[strategyID];
    //     require(
    //         msg.sender == strategy.alpha || msg.sender == strategy.omega,
    //         "A21" // "msg.sender not authorised to exercise strategy"
    //     );

    //     // Verify if collateral information provided is valid and sufficiently up-to-date.
    //     // Note we use the internal helper function to read the strategy params from storage.
    //     Utils.checkWeb2SignatureForPayout(
    //         CollateralParamsFull(
    //             strategy.expiry,
    //             _paramsID.alphaCollateralRequirement,
    //             _paramsID.omegaCollateralRequirement,
    //             _paramsID.ora_oracleNonce,
    //             strategy.bra,
    //             strategy.ket,
    //             strategy.basis,
    //             strategy.amplitude,
    //             strategy.maxNotional,
    //             strategy.phase
    //         ),
    //         _signature,
    //         collateralManager.Web2Address()
    //     );

    //     // If alpha has the payout requirement, alpha pays omega and vice-versa.
    //     // Assume one of them is always zero and one is always the payout.
    //     // Payout when the first party calls exercise.
    //     if (strategy.alpha != address(0) && strategy.omega != address(0)) {
    //         // Calculate the payout amount
    //         uint256 payout;

    //         uint256 alphaAllocated = collateralManager.allocatedCollateral(
    //             strategy.alpha,
    //             strategyID
    //         );
    //         uint256 omegaAllocated = collateralManager.allocatedCollateral(
    //             strategy.omega,
    //             strategyID
    //         );
    //         if (alphaAllocated < _paramsID.alphaCollateralRequirement) {
    //             payout = alphaAllocated;
    //         } else if (omegaAllocated < _paramsID.omegaCollateralRequirement) {
    //             payout = omegaAllocated;
    //         } else {
    //             payout = (_paramsID.alphaCollateralRequirement >
    //                 _paramsID.omegaCollateralRequirement)
    //                 ? _paramsID.alphaCollateralRequirement
    //                 : _paramsID.omegaCollateralRequirement;
    //         }
    //         if (_paramsID.alphaCollateralRequirement > 0) {
    //             collateralManager.relocateCollateral(
    //                 strategy.alpha,
    //                 strategy.omega,
    //                 strategyID,
    //                 payout,
    //                 strategy.basis
    //             );
    //         } else if (_paramsID.omegaCollateralRequirement > 0) {
    //             collateralManager.relocateCollateral(
    //                 strategy.omega,
    //                 strategy.alpha,
    //                 strategyID,
    //                 payout,
    //                 strategy.basis
    //             );
    //         }
    //     }

    //     // Deallocate excess collateral
    //     collateralManager.reallocateAllNoCollateralCheck(
    //         msg.sender,
    //         strategyID,
    //         0,
    //         strategy.basis
    //     );

    //     // Remove msg.sender from their side.
    //     if (msg.sender == strategy.alpha) strategy.alpha = address(0);
    //     else strategy.omega = address(0);

    //     if (strategy.alpha == address(0) && strategy.omega == address(0)) {
    //         delete strategies[strategyID];
    //         delete strategyNonce[strategyID];
    //         emit Deleted(_paramsID.strategyID);
    //     }
    //     emit Exercised(_paramsID.strategyID, msg.sender);
    // }

    // function liquidate(
    //     LiquidationParams calldata _liquidationParams,
    //     uint256 _strategyId,
    //     bytes calldata _liquidationSignature
    // ) external {
    //     require(msg.sender == liquidator, "A1");

    //     Strategy storage strategy = strategies[_strategyId];

    //     Utils.checkLiquidationSignature(
    //         _liquidationParams,
    //         strategy,
    //         _liquidationSignature,
    //         collateralManager.Web2Address()
    //     );

    //     // Reduce strategy's amplitude to maintain collateralisation
    //     strategy.amplitude = _liquidationParams.newAmplitude;
    //     strategy.maxNotional = _liquidationParams.newMaxNotional;

    //     collateralManager.executeLiquidation(
    //         _liquidationParams,
    //         _strategyId,
    //         strategy.alpha,
    //         strategy.omega,
    //         strategy.basis
    //     );

    //     emit Liquidated(_strategyId);
    // }
}
