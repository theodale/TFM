// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../misc/Types.sol";
import "../libraries/Utils.sol";
import "./CollateralManager.sol";
import "../interfaces/ITFM.sol";

import "hardhat/console.sol";

contract TFM is
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

    // Stores strategy states
    mapping(uint256 => Strategy) internal strategies;

    // Stores next strategy ID
    uint256 public strategyCounter;

    // Address permitted to perform liquidations
    address internal liquidator;

    // Protocol's collateral management contract
    CollateralManager public collateralManager;

    // Prevent replay of strategy action meta-transactions
    mapping(uint256 => uint256) public strategyNonce;

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

    // *** ADMIN SETTERS ***

    function setLiquidatorAddress(address _liquidator) public onlyOwner {
        liquidator = _liquidator;
    }

    function setCollateralManagerAddress(
        address _collateralManager
    ) external onlyOwner {
        collateralManager = CollateralManager(_collateralManager);
    }

    // *** STRATEGY ACTIONS ***

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

        _incrementMintNonce(
            _spearmintParameters.alpha,
            _spearmintParameters.omega
        );

        emit Spearmint(strategyId);
    }

    // *** LIQUIDATION ***

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
}
