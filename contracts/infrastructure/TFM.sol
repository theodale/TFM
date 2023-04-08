// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../libraries/Utils.sol";
import "../interfaces/ICollateralManager.sol";
import "../interfaces/ITFM.sol";
import "../misc/Types.sol";

import "hardhat/console.sol";

// **************************************** THE FIELD MACHINE ****************************************
// A peer-to-peer options trading base layer
// Created by Field Labs
contract TFM is ITFM, OwnableUpgradeable, UUPSUpgradeable {
    // *** STATE VARIABLES ***

    // Signs and validates data packages
    address trufinOracle;

    // Used to ensure oracle terms are up to date => updated periodically
    uint256 public oracleNonce;

    // Time at which the oracle nonce was last updated
    uint256 latestOracleNonceUpdateTime;

    // Contract will lock itself if the oracle nonce has not been updated in the last `lockTime` seconds
    uint256 lockTime;

    // Prevents replay attacks using spearmint signatures
    // See getMintNonce() function for key/value meanings
    mapping(address => mapping(address => uint256)) internal mintNonce;

    // Stores strategy states
    // Maps strategy ID => strategy
    mapping(uint256 => Strategy) private strategies;

    // Stores ID of the next strategy to be minted
    uint256 public strategyCounter;

    // Address permitted to perform liquidations
    address internal liquidator;

    // Performs collateral related logic for the TFM
    ICollateralManager public collateralManager;

    // *** INITIALIZER ***

    function initialize(
        ICollateralManager _collateralManager,
        address _owner,
        address _liquidator,
        address _trufinOracle,
        uint256 _lockTime
    ) external initializer {
        // Initialize inherited state
        __Ownable_init();
        transferOwnership(_owner);
        __UUPSUpgradeable_init();

        // Initialize contract state
        liquidator = _liquidator;
        collateralManager = _collateralManager;
        trufinOracle = _trufinOracle;
        lockTime = _lockTime;
        latestOracleNonceUpdateTime = block.timestamp;
    }

    // *** GETTERS ***

    // Returns the mint nonce of a pair of users
    function getMintNonce(address partyOne, address partyTwo) public view returns (uint256) {
        if (partyOne < partyTwo) {
            return mintNonce[partyOne][partyTwo];
        } else {
            return mintNonce[partyTwo][partyOne];
        }
    }

    // Read a strategy with a certain ID
    function getStrategy(uint256 _strategyID) external view returns (Strategy memory) {
        return strategies[_strategyID];
    }

    // *** STRATEGY ACTIONS ***

    // Mint a new strategy between two parties
    // Signatures verify parties approval
    function spearmint(
        MintTerms calldata _terms,
        MintParameters calldata _parameters,
        bytes calldata _alphaSignature,
        bytes calldata _omegaSignature
    ) external {
        Utils.validateMintTerms(_terms, _parameters.oracleSignature, trufinOracle);

        Utils.ensureSpearmintApprovals(
            _parameters,
            getMintNonce(_parameters.alpha, _parameters.omega),
            _alphaSignature,
            _omegaSignature
        );

        _checkOracleNonce(_terms.oracleNonce);

        uint256 strategyId = _createStrategy(_terms, _parameters);

        collateralManager.spearmint(
            strategyId,
            _parameters.alpha,
            _parameters.omega,
            _terms.basis,
            _terms.alphaCollateralRequirement,
            _terms.omegaCollateralRequirement,
            _terms.alphaFee,
            _terms.omegaFee,
            _parameters.premium
        );

        _incrementMintNonce(_parameters.alpha, _parameters.omega);

        emit Spearmint(strategyId);
    }

    // Approved third party mints a strategy for two users
    function peppermint(MintTerms calldata _terms, MintParameters calldata _parameters) external {
        Utils.validateMintTerms(_terms, _parameters.oracleSignature, trufinOracle);

        _checkOracleNonce(_terms.oracleNonce);

        uint256 strategyId = _createStrategy(_terms, _parameters);

        _incrementMintNonce(_parameters.alpha, _parameters.omega);

        // collateralManager.peppermint(
        //     strategyId,
        //     _parameters.alpha,
        //     _parameters.omega,
        //     _terms.basis,
        //     _terms.alphaCollateralRequirement,
        //     _terms.omegaCollateralRequirement,
        //     _terms.alphaFee,
        //     _terms.omegaFee,
        //     _parameters.premium
        // );

        emit Peppermint(strategyId);
    }

    // Transfer a strategy position
    // Ensure correct collateral and security flow when transferring to self
    function transfer(TransferTerms calldata _terms, TransferParameters calldata _parameters) external {
        Strategy storage strategy = strategies[_parameters.strategyId];

        Utils.validateTransferTerms(_terms, strategy, trufinOracle, _parameters.oracleSignature);

        address sender = _terms.alphaTransfer ? strategy.alpha : strategy.omega;

        Utils.ensureTransferApprovals(_parameters, strategy, sender, _terms.alphaTransfer);

        _checkOracleNonce(_terms.oracleNonce);

        collateralManager.transfer(
            _parameters.strategyId,
            sender,
            _parameters.recipient,
            strategy.basis,
            _terms.recipientCollateralRequirement,
            _terms.senderFee,
            _terms.recipientFee,
            _parameters.premium
        );

        // Increment strategy's action nonce to prevent signature replay
        strategy.actionNonce++;

        // Update state to reflect postition transfer
        if (_terms.alphaTransfer) {
            strategy.alpha = _parameters.recipient;
        } else {
            strategy.omega = _parameters.recipient;
        }

        emit Transfer(_parameters.strategyId);
    }

    // Combine two strategies into one
    // We delete one strategy (strategyTwo) and overwrite the other (strategyOne) into the new combined strategy
    // This combined strategy has strategyOne's alpha and omega  => terms offered for this direction
    function combine(CombinationTerms calldata _terms, CombinationParameters calldata _parameters) external {
        Strategy storage strategyOne = strategies[_parameters.strategyOneId];
        Strategy storage strategyTwo = strategies[_parameters.strategyTwoId];

        _checkOracleNonce(_terms.oracleNonce);

        Utils.checkCombinationApprovals(
            _parameters.strategyOneId,
            _parameters.strategyTwoId,
            strategyOne,
            strategyTwo,
            _parameters.strategyOneAlphaSignature,
            _parameters.strategyOneOmegaSignature,
            _parameters.oracleSignature
        );

        Utils.validateCombinationTerms(_terms, strategyOne, strategyTwo, trufinOracle, _parameters.oracleSignature);

        collateralManager.combine(
            _parameters.strategyOneId,
            _parameters.strategyTwoId,
            strategyOne.alpha,
            strategyOne.omega,
            strategyOne.basis,
            _terms.resultingAlphaCollateralRequirement,
            _terms.resultingOmegaCollateralRequirement,
            _terms.strategyOneAlphaFee,
            _terms.strategyOneOmegaFee
        );

        // Minimally alter strategy one to combined form
        strategyOne.phase = _terms.resultingPhase;
        strategyOne.amplitude = _terms.resultingAmplitude;

        // Deleting strategy two prevents approval signature replay => no need to increment strategy one's action nonce
        _deleteStrategy(_parameters.strategyTwoId);

        emit Combination(_parameters.strategyOneId, _parameters.strategyTwoId);
    }

    // Alter two same-phase strategies shared between parties to reduce overall collateral requirements
    function novate(NovationTerms calldata _terms, NovationParameters calldata _parameters) external {
        Strategy storage strategyOne = strategies[_parameters.strategyOneId];
        Strategy storage strategyTwo = strategies[_parameters.strategyTwoId];

        _checkOracleNonce(_terms.oracleNonce);

        Utils.validateNovationTerms(_terms, strategyOne, strategyTwo, trufinOracle, _parameters.oracleSignature);

        Utils.checkNovationApprovals(_parameters, strategyOne, strategyTwo);

        address strategyOneAlpha = strategyOne.alpha;
        address strategyTwoOmega = strategyTwo.omega;

        // Oracle signs novations with the middle party as omega in strategy one and alpha in strategy two
        require(strategyOneAlpha == strategyOne.omega, "NOVATION: Strategies do not have required middle party");

        // Update first strategy to novated state
        strategyOne.omega = strategyTwoOmega;
        strategyOne.amplitude = _terms.strategyOneResultingAmplitude;

        // Strategy two may be deleted
        if (_terms.strategyTwoResultingAmplitude != 0) {
            strategyTwo.alpha = _parameters.updateStrategyTwoOmega ? strategyOneAlpha : strategyTwoOmega;
            strategyTwo.amplitude = _terms.strategyTwoResultingAmplitude;
        } else {
            _deleteStrategy(_parameters.strategyTwoId);
        }

        // collateralManager.novate();

        emit Novation(_parameters.strategyOneId, _parameters.strategyTwoId);
    }

    // Call to finalise a strategy's positions after it has expired
    function exercise(ExerciseTerms calldata _terms, ExerciseParameters calldata _parameters) external {
        _checkOracleNonce(_terms.oracleNonce);

        Strategy storage strategy = strategies[_parameters.strategyId];

        Utils.validateExerciseTerms(_terms, strategy, trufinOracle, _parameters.oracleSignature);

        collateralManager.exercise(
            _parameters.strategyId,
            strategy.alpha,
            strategy.omega,
            strategy.basis,
            _terms.payout
        );

        _deleteStrategy(_parameters.strategyId);

        emit Exercise(_parameters.strategyId);
    }

    // // *** MAINTENANCE ***

    // function updateOracleNonce(uint256 _oracleNonce, bytes calldata _oracleSignature) external {
    //     // Prevents replay of out-of-date signatures
    //     require(_oracleNonce > oracleNonce, "TFM: Oracle nonce can only be increased");

    //     Utils.validateOracleNonceUpdate(_oracleNonce, _oracleSignature, trufinOracle);

    //     // Perform oracle state update
    //     oracleNonce = _oracleNonce;
    //     latestOracleNonceUpdateTime = block.timestamp;

    //     emit OracleNonceUpdated(_oracleNonce);
    // }

    function liquidate(LiquidationTerms calldata _terms, LiquidationParameters calldata _params) external {
        require(msg.sender == liquidator, "TFM: Liquidator only");

        Strategy storage strategy = strategies[_params.strategyId];

        uint256 alphaInitialCollateral = collateralManager.allocations(strategy.alpha, _params.strategyId);
        uint256 omegaInitialCollateral = collateralManager.allocations(strategy.omega, _params.strategyId);

        Utils.validateLiquidationTerms(
            _terms,
            strategy,
            _params.oracleSignature,
            trufinOracle,
            alphaInitialCollateral,
            omegaInitialCollateral
        );

        // Reduce strategy's amplitude to maintain collateralisation
        strategy.amplitude = _terms.postLiquidationAmplitude;

        collateralManager.liquidate(
            _params.strategyId,
            strategy.alpha,
            strategy.omega,
            _terms.compensation,
            strategy.basis,
            _terms.alphaPenalisation,
            _terms.omegaPenalisation
        );

        emit Liquidation(_params.strategyId);
    }

    // *** ADMIN SETTERS ***

    // function setLiquidator(address _liquidator) public onlyOwner {
    //     liquidator = _liquidator;
    // }

    // function setCollateralManager(address _collateralManager) external onlyOwner {
    //     collateralManager = ICollateralManager(_collateralManager);
    // }

    // *** INTERNAL METHODS ***

    // Internal method that updates a pairs mint nonce
    function _incrementMintNonce(address partyOne, address partyTwo) private {
        if (partyOne < partyTwo) {
            mintNonce[partyOne][partyTwo]++;
        } else {
            mintNonce[partyTwo][partyOne]++;
        }
    }

    // Performs oracle nonce-related checks
    function _checkOracleNonce(uint256 _oracleNonce) internal view {
        // Ensure input nonce is not outdated
        require((_oracleNonce <= oracleNonce) && (oracleNonce - _oracleNonce <= 1), "TFM: Oracle nonce has expired");

        // Check whether contract is locked due to oracle nonce not being updated
        require(
            (block.timestamp < latestOracleNonceUpdateTime + lockTime),
            "TFM: Contract locked as oracle nonce has not been updated"
        );
    }

    // Creates a new strategy and returns its ID
    function _createStrategy(
        MintTerms calldata _terms,
        MintParameters calldata _parameters
    ) internal returns (uint256) {
        uint256 newStrategyId = strategyCounter++;

        // Check gas cost compared to Strategy(...) => this methods avoid writing actionNonce = 0
        strategies[newStrategyId].transferable = _parameters.transferable;
        strategies[newStrategyId].bra = _terms.bra;
        strategies[newStrategyId].ket = _terms.ket;
        strategies[newStrategyId].basis = _terms.basis;
        strategies[newStrategyId].alpha = _parameters.alpha;
        strategies[newStrategyId].omega = _parameters.omega;
        strategies[newStrategyId].expiry = _terms.expiry;
        strategies[newStrategyId].amplitude = _terms.amplitude;
        strategies[newStrategyId].phase = _terms.phase;

        return newStrategyId;
    }

    function _deleteStrategy(uint256 _strategyId) internal {
        // Also delete CM state
        delete strategies[_strategyId];
    }

    // Upgrade authorization
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
