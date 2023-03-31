// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../misc/Types.sol";
import "../libraries/Utils.sol";
import "../interfaces/ICollateralManager.sol";
import "../interfaces/ITFM.sol";

import "hardhat/console.sol";

// **************************************** THE FIELD MACHINE ****************************************
// A peer-to-peer options trading base layer
contract TFM is ReentrancyGuardUpgradeable, OwnableUpgradeable, UUPSUpgradeable, ITFM {
    // *** STATE VARIABLES ***

    // Signs and validates data packages
    address trufinOracle;

    // Used to ensure only recent data packages are valid => updated periodically
    uint256 public oracleNonce;

    // Time at which the oracle nonce was last updated
    uint256 latestOracleNonceUpdateTime;

    // Contract will lock itself if the oracle nonce has not been updated in the last `lockTime` seconds
    uint256 lockTime;

    // Prevents replay attacks using spearminter signatures
    // See getMintNonce() function for key/value meanings
    mapping(address => mapping(address => uint256)) internal mintNonce;

    // Stores strategy states
    // Mapts strategy ID => strategy
    mapping(uint256 => Strategy) internal strategies;

    // Stores ID of the next strategy to be minted
    uint256 public strategyCounter;

    // Address permitted to perform liquidations
    address internal liquidator;

    // Protocol's collateral management contract
    ICollateralManager public collateralManager;

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
        __UUPSUpgradeable_init();

        // Set relevant addresses & contracts
        liquidator = _liquidator;
        collateralManager = ICollateralManager(_collateralManager);
        trufinOracle = _trufinOracle;
        lockTime = 2 hours;
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

    // *** ADMIN SETTERS ***

    function setLiquidator(address _liquidator) public onlyOwner {
        liquidator = _liquidator;
    }

    function setCollateralManager(address _collateralManager) external onlyOwner {
        collateralManager = ICollateralManager(_collateralManager);
    }

    // *** STRATEGY ACTIONS ***

    // Mint a new strategy
    function spearmint(SpearmintTerms calldata _terms, SpearmintParameters calldata _parameters) external {
        Utils.validateSpearmintTerms(_terms, _parameters.oracleSignature, trufinOracle);

        Utils.ensureSpearmintApprovals(_parameters, getMintNonce(_parameters.alpha, _parameters.omega));

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

    function peppermint() external {}

    // Transfer a strategy position
    // Ensure correct collateral and security flow when trasnferring to self
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

        // Increment strategy's action nonce to prevent replay using _signatures
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

        // Minimally alter strategy one to combimed form
        strategyOne.phase = _terms.resultingPhase;
        strategyOne.amplitude = _terms.resultingAmplitude;

        _deleteStrategy(_parameters.strategyTwoId);

        emit Combination(_parameters.strategyOneId, _parameters.strategyTwoId);
    }

    // Call to finalise a position on a strategy
    // Unallocates collateral not used for a payout
    // No alpha/omega split like in trufin_v2
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

    function updateOracleNonce(uint256 _oracleNonce, bytes calldata _oracleSignature) external {
        // Prevents replay of out-of-date signatures
        require(_oracleNonce > oracleNonce, "TFM: Oracle nonce can only be increased");

        Utils.validateOracleNonceUpdate(_oracleNonce, _oracleSignature, trufinOracle);

        // Perform oracle state update
        oracleNonce = _oracleNonce;
        latestOracleNonceUpdateTime = block.timestamp;

        emit OracleNonceUpdated(_oracleNonce);
    }

    // *** LIQUIDATION ***

    function liquidate(LiquidationTerms calldata _terms, LiquidationParameters calldata _params) external {
        require(msg.sender == liquidator, "TFM: Liquidator only");

        Strategy storage strategy = strategies[_params.strategyId];

        uint256 alphaInitialCollateral = collateralManager.allocatedCollateral(strategy.alpha, _params.strategyId);
        uint256 omegaInitialCollateral = collateralManager.allocatedCollateral(strategy.omega, _params.strategyId);

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
            _terms.alphaFee,
            _terms.omegaFee
        );

        emit Liquidation(_params.strategyId);
    }

    // *** INTERNAL METHODS ***

    // Creates a new strategy and returns its ID
    function _createStrategy(
        SpearmintTerms calldata _terms,
        SpearmintParameters calldata _parameters
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
        // Check whether input nonce is outdated
        require((_oracleNonce <= oracleNonce) && (oracleNonce - _oracleNonce <= 1), "TFM: Oracle nonce has expired");

        // Check whether contract is locked due to oracle nonce not being updated
        require(
            (block.timestamp < latestOracleNonceUpdateTime + lockTime),
            "TFM: Contract locked due as oracle nonce has not been updated"
        );
    }

    function _deleteStrategy(uint256 _strategyId) internal {
        // Also delete CM state
        delete strategies[_strategyId];
    }

    // Upgrade authorization
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
