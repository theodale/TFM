// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IActionLayer.sol";
import "../interfaces/IAssetLayer.sol";
import "../libraries/Validator.sol";
import "../interfaces/ITrufinWallet.sol";
import "../misc/Types.sol";

import "hardhat/console.sol";

/// @title TFM Action Layer
/// @author Field Labs
contract ActionLayer is IActionLayer, OwnableUpgradeable, UUPSUpgradeable {
    // *** STATE VARIABLES ***

    /// @notice Current value of the TFM's oracle nonce.
    uint256 public oracleNonce;

    /// @notice Stores ID of the next strategy to be minted.
    uint256 public strategyCounter;

    // The AssetLayer contract being utilised by this ActionLayer
    IAssetLayer assetLayer;

    // Signs and validates data packages
    address oracle;

    // Time at which the oracle nonce was last updated
    uint256 latestOracleNonceUpdateTime;

    // Contract will lock itself if the oracle nonce has not been updated within this many seconds
    uint256 selfLockPeriod;

    // Address permitted to perform liquidations
    address liquidator;

    // Prevents replay attacks using spearmint signatures
    // See getMintNonce() function for key/value meanings
    mapping(address => mapping(address => uint256)) mintNonce;

    // Stores strategy states
    // Maps strategy ID => strategy
    mapping(uint256 => Strategy) strategies;

    // *** INITIALIZER ***

    function initialize(
        address _owner,
        address _liquidator,
        address _oracle,
        uint256 _selfLockPeriod,
        IAssetLayer _assetLayer
    ) external initializer {
        // Initialize inherited state
        __Ownable_init();
        transferOwnership(_owner);
        __UUPSUpgradeable_init();

        // Initialize contract state
        liquidator = _liquidator;
        oracle = _oracle;
        selfLockPeriod = _selfLockPeriod;
        latestOracleNonceUpdateTime = block.timestamp;
        assetLayer = _assetLayer;
    }

    // *** GETTERS ***

    /// @notice Get the mint nonce of a pair of users.
    function getMintNonce(address partyOne, address partyTwo) public view returns (uint256) {
        if (partyOne < partyTwo) {
            return mintNonce[partyOne][partyTwo];
        } else {
            return mintNonce[partyTwo][partyOne];
        }
    }

    /// @notice Get a strategy with a certain ID.
    function getStrategy(uint256 _strategyID) external view returns (Strategy memory) {
        return strategies[_strategyID];
    }

    // *** STRATEGY ACTIONS ***

    /// @notice Mint a new strategy between two parties.
    /// @dev Signatures verify parties' willingness to mint the strategy.
    function spearmint(SpearmintParameters calldata _parameters) external {
        _checkOracleNonce(_parameters.oracleNonce);

        uint256 strategyId = _createStrategy(
            _parameters.alpha,
            _parameters.omega,
            _parameters.expiry,
            _parameters.bra,
            _parameters.ket,
            _parameters.basis,
            _parameters.amplitude,
            _parameters.phase,
            _parameters.transferable
        );

        Validator.approveSpearmint(_parameters, oracle, getMintNonce(_parameters.alpha, _parameters.omega));

        assetLayer.executeSpearmint(
            strategyId,
            _parameters.alpha,
            _parameters.omega,
            _parameters.basis,
            _parameters.premium,
            _parameters.alphaCollateralRequirement,
            _parameters.omegaCollateralRequirement,
            _parameters.alphaFee,
            _parameters.omegaFee
        );

        _incrementMintNonce(_parameters.alpha, _parameters.omega);

        emit Spearmint(strategyId);
    }

    /// @notice Approved calling third party mints a strategy for two users.
    /// @dev Making deposits to a third party authorizes counterparty willingness to mint the strategy.
    function peppermint(PeppermintParameters calldata _parameters) external {
        ApprovePeppermintParameters memory approvePeppermintParameters = ApprovePeppermintParameters(
            _parameters.expiry,
            _parameters.alphaCollateralRequirement,
            _parameters.omegaCollateralRequirement,
            _parameters.alphaFee,
            _parameters.omegaFee,
            _parameters.oracleNonce,
            _parameters.bra,
            _parameters.ket,
            _parameters.basis,
            _parameters.amplitude,
            _parameters.phase,
            oracle,
            _parameters.oracleSignature
        );

        Validator.approvePeppermint(approvePeppermintParameters);

        _checkOracleNonce(_parameters.oracleNonce);

        uint256 strategyId = _createStrategy(
            _parameters.alpha,
            _parameters.omega,
            _parameters.expiry,
            _parameters.bra,
            _parameters.ket,
            _parameters.basis,
            _parameters.amplitude,
            _parameters.phase,
            _parameters.transferable
        );

        ExecutePeppermintParameters memory peppermintParameters = ExecutePeppermintParameters(
            strategyId,
            _parameters.alpha,
            _parameters.omega,
            _parameters.basis,
            _parameters.premium,
            _parameters.alphaCollateralRequirement,
            _parameters.omegaCollateralRequirement,
            _parameters.alphaFee,
            _parameters.omegaFee,
            msg.sender,
            _parameters.alphaDepositId,
            _parameters.omegaDepositId
        );

        assetLayer.executePeppermint(peppermintParameters);

        _incrementMintNonce(_parameters.alpha, _parameters.omega);

        emit Peppermint(strategyId);
    }

    /// @notice Used by a strategy party to transfer their position.
    /// @dev Sender and recipient signatures required for approval. Static party signature only required if strategy is non-transferable.
    function transfer(TransferParameters calldata _parameters) external {
        Strategy storage strategy = strategies[_parameters.strategyId];

        _checkOracleNonce(_parameters.oracleNonce);

        address sender = _parameters.alphaTransfer ? strategy.alpha : strategy.omega;

        Validator.approveTransfer(_parameters, strategy, sender, oracle);

        ExecuteTransferParameters memory executeTransferParameters = ExecuteTransferParameters(
            _parameters.strategyId,
            sender,
            _parameters.recipient,
            strategy.basis,
            _parameters.recipientCollateralRequirement,
            _parameters.senderFee,
            _parameters.recipientFee,
            _parameters.premium,
            _parameters.alphaTransfer
        );

        assetLayer.executeTransfer(executeTransferParameters);

        // Increment strategy's action nonce to prevent signature replay
        strategy.actionNonce++;

        // Update state to reflect postition transfer
        if (_parameters.alphaTransfer) {
            strategy.alpha = _parameters.recipient;
        } else {
            strategy.omega = _parameters.recipient;
        }

        emit Transfer(_parameters.strategyId);
    }

    /// @notice Used to combine two strategies shared between two parties into one.
    /// @dev We delete one strategy (strategyTwo) and overwrite the other (strategyOne) into the new combined strategy.
    /// @dev The combined strategy has strategy one's alpha and omega.
    function combine(CombinationParameters calldata _parameters) external {
        _checkOracleNonce(_parameters.oracleNonce);

        Strategy storage strategyOne = strategies[_parameters.strategyOneId];
        Strategy storage strategyTwo = strategies[_parameters.strategyTwoId];

        Validator.approveCombination(_parameters, strategyOne, strategyTwo, oracle);

        ExecuteCombinationParameters memory executeCombinationParameters = ExecuteCombinationParameters(
            _parameters.strategyOneId,
            _parameters.strategyTwoId,
            _parameters.resultingAlphaCollateralRequirement,
            _parameters.resultingOmegaCollateralRequirement,
            strategyOne.basis,
            strategyOne.alpha,
            strategyOne.omega,
            _parameters.strategyOneAlphaFee,
            _parameters.strategyOneOmegaFee,
            _parameters.aligned
        );

        assetLayer.executeCombination(executeCombinationParameters);

        // Minimally alter strategy one to combined form
        strategyOne.phase = _parameters.resultingPhase;
        strategyOne.amplitude = _parameters.resultingAmplitude;

        // Deleting strategy two prevents approval signature replay => no need to increment strategy one's action nonce
        _deleteStrategy(_parameters.strategyTwoId);

        emit Combination(_parameters.strategyOneId, _parameters.strategyTwoId);
    }

    // // Alter two same-phase strategies shared between parties to reduce overall collateral requirements
    // function novate(NovationTerms calldata _terms, NovationParameters calldata _parameters) external {
    //     Strategy storage strategyOne = strategies[_parameters.strategyOneId];
    //     Strategy storage strategyTwo = strategies[_parameters.strategyTwoId];

    //     _checkOracleNonce(_terms.oracleNonce);

    //     Utils.validateNovationTerms(_terms, strategyOne, strategyTwo, oracle, _parameters.oracleSignature);

    //     Utils.checkNovationApprovals(_parameters, strategyOne, strategyTwo);

    //     // assetLayer.novate();

    //     emit Novation(_parameters.strategyOneId, _parameters.strategyTwoId);
    // }

    // Call to finalise a strategy's positions after it has expired
    function exercise(ExerciseParameters calldata _parameters) external {
        _checkOracleNonce(_parameters.oracleNonce);

        Strategy storage strategy = strategies[_parameters.strategyId];

        Validator.approveExercise(
            _parameters.payout,
            _parameters.oracleNonce,
            _parameters.oracleSignature,
            strategy,
            oracle
        );

        assetLayer.executeExercise(
            _parameters.strategyId,
            strategy.alpha,
            strategy.omega,
            strategy.basis,
            _parameters.payout
        );

        _deleteStrategy(_parameters.strategyId);

        emit Exercise(_parameters.strategyId);
    }

    // *** MAINTENANCE ***

    function liquidate(LiquidationParameters calldata _parameters) external {
        require(msg.sender == liquidator, "TFM: Liquidator only");

        Strategy storage strategy = strategies[_parameters.strategyId];

        uint256 alphaInitialCollateral = assetLayer.getAllocation(strategy.alpha, _parameters.strategyId, true);
        uint256 omegaInitialCollateral = assetLayer.getAllocation(strategy.omega, _parameters.strategyId, false);

        ApproveLiquidationParameters memory approveLiquidationParameters = ApproveLiquidationParameters(
            _parameters.oracleNonce,
            _parameters.compensation,
            _parameters.alphaPenalisation,
            _parameters.omegaPenalisation,
            _parameters.postLiquidationAmplitude,
            alphaInitialCollateral,
            omegaInitialCollateral,
            oracle,
            _parameters.oracleSignature
        );

        Validator.approveLiquidation(approveLiquidationParameters, strategy);

        // Reduce strategy's amplitude to maintain collateralisation
        strategy.amplitude = _parameters.postLiquidationAmplitude;

        // assetLayer.liquidate(
        //     _params.strategyId,
        //     strategy.alpha,
        //     strategy.omega,
        //     _terms.compensation,
        //     strategy.basis,
        //     _terms.alphaPenalisation,
        //     _terms.omegaPenalisation
        // );

        emit Liquidation(_parameters.strategyId);
    }

    // function updateOracleNonce(uint256 _oracleNonce, bytes calldata _oracleSignature) external {
    //     // Prevents replay of out-of-date signatures
    //     require(_oracleNonce > oracleNonce, "TFM: Oracle nonce can only be increased");

    //     Utils.validateOracleNonceUpdate(_oracleNonce, _oracleSignature, oracle);

    //     // Perform oracle state update
    //     oracleNonce = _oracleNonce;
    //     latestOracleNonceUpdateTime = block.timestamp;

    //     emit OracleNonceUpdated(_oracleNonce);
    // }

    // // *** ADMIN SETTERS ***

    function setLiquidator(address _liquidator) public onlyOwner {
        liquidator = _liquidator;
    }

    function setassetLayer(address _assetLayer) external onlyOwner {
        assetLayer = IAssetLayer(_assetLayer);
    }

    // // *** METHODS ***

    // method that updates a pairs mint nonce
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
            (block.timestamp < latestOracleNonceUpdateTime + selfLockPeriod),
            "TFM: Contract locked as oracle nonce has not been updated"
        );
    }

    // Creates a new strategy and returns its ID
    function _createStrategy(
        address _alpha,
        address _omega,
        uint48 _expiry,
        address _bra,
        address _ket,
        address _basis,
        int256 _amplitude,
        int256[2][] memory _phase,
        bool _transferable
    ) internal returns (uint256) {
        uint256 newStrategyId = strategyCounter++;

        Strategy storage strategy = strategies[newStrategyId];

        strategy.alpha = _alpha;
        strategy.omega = _omega;
        strategy.transferable = _transferable;
        strategy.bra = _bra;
        strategy.ket = _ket;
        strategy.basis = _basis;
        strategy.expiry = _expiry;
        strategy.amplitude = _amplitude;
        strategy.phase = _phase;

        return newStrategyId;
    }

    function _deleteStrategy(uint256 _strategyId) internal {
        // Also delete CM state? => or does this save bytecode
        delete strategies[_strategyId];
    }

    // Upgrade authorization
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
