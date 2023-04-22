// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/ITFM.sol";
import "../interfaces/IFundManager.sol";
import "../libraries/Validator.sol";
import "../interfaces/IWallet.sol";
import "../misc/Types.sol";

import "hardhat/console.sol";

/// @title The Field Machine
/// @author Field Labs
/// @notice A peer-to-peer options trading base layer
contract TFM is ITFM, OwnableUpgradeable, UUPSUpgradeable {
    // *** STATE VARIABLES ***

    /// @notice Current value of the TFM's oracle nonce.
    uint256 public oracleNonce;

    /// @notice Stores ID of the next strategy to be minted.
    uint256 public strategyCounter;

    // The FundManager contract being utilised by this TFM
    IFundManager fundManager;

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
        IFundManager _fundManager
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
        fundManager = _fundManager;
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

        fundManager.executeSpearmint(
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

        fundManager.executePeppermint(peppermintParameters);

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

        fundManager.executeTransfer(executeTransferParameters);

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

    // // Combine two strategies into one
    // // We delete one strategy (strategyTwo) and overwrite the other (strategyOne) into the new combined strategy
    // // This combined strategy has strategyOne's alpha and omega  => terms offered for this direction
    // function combine(CombinationTerms calldata _terms, CombinationParameters calldata _parameters) external {
    //     Strategy storage strategyOne = strategies[_parameters.strategyOneId];
    //     Strategy storage strategyTwo = strategies[_parameters.strategyTwoId];

    //     _checkOracleNonce(_terms.oracleNonce);

    //     Utils.checkCombinationApprovals(
    //         _parameters.strategyOneId,
    //         _parameters.strategyTwoId,
    //         strategyOne,
    //         strategyTwo,
    //         _parameters.strategyOneAlphaSignature,
    //         _parameters.strategyOneOmegaSignature,
    //         _parameters.oracleSignature
    //     );

    //     Utils.validateCombinationTerms(_terms, strategyOne, strategyTwo, oracle, _parameters.oracleSignature);

    //     fundManager.combine(
    //         _parameters.strategyOneId,
    //         _parameters.strategyTwoId,
    //         strategyOne.alpha,
    //         strategyOne.omega,
    //         strategyOne.basis,
    //         _terms.resultingAlphaCollateralRequirement,
    //         _terms.resultingOmegaCollateralRequirement,
    //         _terms.strategyOneAlphaFee,
    //         _terms.strategyOneOmegaFee
    //     );

    //     // Minimally alter strategy one to combined form
    //     strategyOne.phase = _terms.resultingPhase;
    //     strategyOne.amplitude = _terms.resultingAmplitude;

    //     // Deleting strategy two prevents approval signature replay => no need to increment strategy one's action nonce
    //     _deleteStrategy(_parameters.strategyTwoId);

    //     emit Combination(_parameters.strategyOneId, _parameters.strategyTwoId);
    // }

    // // Alter two same-phase strategies shared between parties to reduce overall collateral requirements
    // function novate(NovationTerms calldata _terms, NovationParameters calldata _parameters) external {
    //     Strategy storage strategyOne = strategies[_parameters.strategyOneId];
    //     Strategy storage strategyTwo = strategies[_parameters.strategyTwoId];

    //     _checkOracleNonce(_terms.oracleNonce);

    //     Utils.validateNovationTerms(_terms, strategyOne, strategyTwo, oracle, _parameters.oracleSignature);

    //     Utils.checkNovationApprovals(_parameters, strategyOne, strategyTwo);

    //     // fundManager.novate();

    //     emit Novation(_parameters.strategyOneId, _parameters.strategyTwoId);
    // }

    // // Call to finalise a strategy's positions after it has expired
    // function exercise(ExerciseTerms calldata _terms, ExerciseParameters calldata _parameters) external {
    //     _checkOracleNonce(_terms.oracleNonce);

    //     Strategy storage strategy = strategies[_parameters.strategyId];

    //     Utils.validateExerciseTerms(_terms, strategy, oracle, _parameters.oracleSignature);

    //     fundManager.exercise(
    //         _parameters.strategyId,
    //         strategy.alpha,
    //         strategy.omega,
    //         strategy.basis,
    //         _terms.payout
    //     );

    //     _deleteStrategy(_parameters.strategyId);

    //     emit Exercise(_parameters.strategyId);
    // }

    // // *** MAINTENANCE ***

    // function updateOracleNonce(uint256 _oracleNonce, bytes calldata _oracleSignature) external {
    //     // Prevents replay of out-of-date signatures
    //     require(_oracleNonce > oracleNonce, "TFM: Oracle nonce can only be increased");

    //     Utils.validateOracleNonceUpdate(_oracleNonce, _oracleSignature, oracle);

    //     // Perform oracle state update
    //     oracleNonce = _oracleNonce;
    //     latestOracleNonceUpdateTime = block.timestamp;

    //     emit OracleNonceUpdated(_oracleNonce);
    // }

    // function liquidate(LiquidationTerms calldata _terms, LiquidationParameters calldata _params) external {
    //     require(msg.sender == liquidator, "TFM: Liquidator only");

    //     Strategy storage strategy = strategies[_params.strategyId];

    //     uint256 alphaInitialCollateral = fundManager.allocations(strategy.alpha, _params.strategyId);
    //     uint256 omegaInitialCollateral = fundManager.allocations(strategy.omega, _params.strategyId);

    //     Utils.validateLiquidationTerms(
    //         _terms,
    //         strategy,
    //         _params.oracleSignature,
    //         oracle,
    //         alphaInitialCollateral,
    //         omegaInitialCollateral
    //     );

    //     // Reduce strategy's amplitude to maintain collateralisation
    //     strategy.amplitude = _terms.postLiquidationAmplitude;

    //     fundManager.liquidate(
    //         _params.strategyId,
    //         strategy.alpha,
    //         strategy.omega,
    //         _terms.compensation,
    //         strategy.basis,
    //         _terms.alphaPenalisation,
    //         _terms.omegaPenalisation
    //     );

    //     emit Liquidation(_params.strategyId);
    // }

    // // *** ADMIN SETTERS ***

    // function setLiquidator(address _liquidator) public onlyOwner {
    //     liquidator = _liquidator;
    // }

    // function setfundManager(address _fundManager) external onlyOwner {
    //     fundManager = IFundManager(_fundManager);
    // }

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
