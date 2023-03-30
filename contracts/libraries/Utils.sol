// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../misc/Types.sol";

import "hardhat/console.sol";

// TO DO:
// - Ensure no signature replay across actions - do we need enum?
// - Check if use of encodePacked is safe
// - Neaten and minify used of ECDSA -> make one function that prefixes and one that doesn't -> maybe also make a straight prefix function

library Utils {
    // SPEARMINT

    // Checks that alpha and omega have provided signatures to authorise the spearmint
    function ensureSpearmintApprovals(SpearmintParameters calldata _parameters, uint256 _mintNonce) external view {
        bytes memory message = abi.encodePacked(
            _parameters.oracleSignature,
            _parameters.alpha,
            _parameters.omega,
            _parameters.premium,
            _parameters.transferable,
            _mintNonce
        );

        bytes32 hash = _generateMessageHash(message);

        require(
            _isValidSignature(hash, _parameters.alphaSignature, _parameters.alpha),
            "SPEARMINT: Alpha signature invalid"
        );

        require(
            _isValidSignature(hash, _parameters.omegaSignature, _parameters.omega),
            "SPEARMINT: Omega signature invalid"
        );
    }

    function validateSpearmintTerms(
        SpearmintTerms calldata _terms,
        bytes calldata _oracleSignature,
        address _oracle
    ) external view {
        bytes memory message = abi.encodePacked(
            _terms.expiry,
            _terms.alphaCollateralRequirement,
            _terms.omegaCollateralRequirement,
            _terms.alphaFee,
            _terms.omegaFee,
            _terms.oracleNonce,
            _terms.bra,
            _terms.ket,
            _terms.basis,
            _terms.amplitude,
            _terms.phase
        );

        require(_isValidSignature(message, _oracleSignature, _oracle), "SPEARMINT: Invalid Trufin oracle signature");
    }

    function ensureTransferApprovals(
        TransferParameters calldata _parameters,
        Strategy storage _strategy,
        address _sender,
        bool alphaTransfer
    ) external view {
        bytes memory message = abi.encodePacked(
            _parameters.oracleSignature,
            _parameters.strategyId,
            _parameters.recipient,
            _parameters.premium
        );

        bytes32 hash = _generateMessageHash(message);

        require(_isValidSignature(hash, _parameters.senderSignature, _sender), "TRANSFER: Sender signature invalid");

        require(
            _isValidSignature(hash, _parameters.recipientSignature, _parameters.recipient),
            "TRANSFER: Recipient signature invalid"
        );

        // Check non-transferring party's signature if strategy is not transferable
        if (!_strategy.transferable) {
            address staticParty = alphaTransfer ? _strategy.omega : _strategy.alpha;

            require(
                _isValidSignature(hash, _parameters.staticPartySignature, staticParty),
                "Static party signature invalid"
            );
        }
    }

    function validateTransferTerms(
        TransferTerms calldata _terms,
        Strategy storage _strategy,
        address _oracle,
        bytes memory _oracleSignature
    ) external view {
        bytes memory message = abi.encodePacked(
            _strategy.expiry,
            _strategy.bra,
            _strategy.ket,
            _strategy.basis,
            _strategy.amplitude,
            _strategy.phase,
            _terms.senderFee,
            _terms.recipientFee,
            _terms.recipientCollateralRequirement,
            _terms.alphaTransfer,
            _terms.oracleNonce
        );

        require(_isValidSignature(message, _oracleSignature, _oracle), "TRANSFER: Invalid Trufin oracle signature");
    }

    // COMBINATION

    function checkCombinationApprovals(
        uint256 _stragegyOneId,
        uint256 _stragegyTwoId,
        Strategy storage _strategyOne,
        Strategy storage _strategyTwo,
        bytes calldata _strategyOneAlphaSignature,
        bytes calldata _strategyOneOmegaSignature,
        bytes calldata _oracleSignature
    ) external view {
        bytes memory message = abi.encodePacked(
            _stragegyOneId,
            _stragegyTwoId,
            _strategyOne.actionNonce,
            _strategyTwo.actionNonce,
            _oracleSignature
        );

        bytes32 hash = _generateMessageHash(message);

        require(
            _isValidSignature(hash, _strategyOneAlphaSignature, _strategyOne.alpha),
            "TFM: Invalid strategy two alpha signature"
        );

        require(
            _isValidSignature(hash, _strategyOneOmegaSignature, _strategyOne.omega),
            "TFM: Invalid strategy one omega signature"
        );
    }

    function validateCombinationTerms(
        CombinationTerms calldata _terms,
        Strategy storage _strategyOne,
        Strategy storage _strategyTwo,
        address _oracle,
        bytes calldata _oracleSignature
    ) external view {
        bool aligned = _getAlignment(_strategyOne, _strategyTwo);

        bytes memory message = abi.encodePacked(
            abi.encodePacked(
                _strategyOne.expiry,
                _strategyOne.bra,
                _strategyOne.ket,
                _strategyOne.basis,
                _strategyOne.amplitude,
                _strategyOne.phase,
                _strategyTwo.expiry,
                _strategyTwo.bra,
                _strategyTwo.ket,
                _strategyTwo.basis
            ),
            abi.encodePacked(
                _strategyTwo.amplitude,
                _strategyTwo.phase,
                _terms.strategyOneAlphaFee,
                _terms.strategyOneOmegaFee,
                _terms.resultingAlphaCollateralRequirement,
                _terms.resultingOmegaCollateralRequirement,
                _terms.resultingPhase
            ),
            abi.encodePacked(_terms.resultingAmplitude, _terms.oracleNonce, aligned)
        );

        require(_isValidSignature(message, _oracleSignature, _oracle), "COMBINATION: Invalid Trufin oracle signature");
    }

    // EXERCISE

    function validateExerciseTerms(
        ExerciseTerms calldata _terms,
        Strategy storage _strategy,
        address _oracle,
        bytes calldata _oracleSignature
    ) external view {
        bytes memory message = abi.encodePacked(
            _strategy.expiry,
            _strategy.bra,
            _strategy.ket,
            _strategy.basis,
            _strategy.amplitude,
            _strategy.phase,
            _terms.oracleNonce,
            _terms.payout
        );

        require(_isValidSignature(message, _oracleSignature, _oracle), "EXERCISE: Invalid Trufin oracle signature");
    }

    // LIQUIDATE

    function validateLiquidationTerms(
        LiquidationTerms calldata _terms,
        Strategy storage _strategy,
        bytes calldata _oracleSignature,
        address _oracle,
        uint256 _initialAlphaAllocation,
        uint256 _initialOmegaAllocation
    ) external view {
        bytes memory message = abi.encodePacked(
            abi.encodePacked(
                _strategy.expiry,
                _strategy.bra,
                _strategy.ket,
                _strategy.basis,
                _strategy.amplitude,
                _strategy.phase,
                _terms.oracleNonce,
                _terms.compensation,
                _terms.alphaFee
            ),
            abi.encodePacked(
                _terms.omegaFee,
                _terms.postLiquidationAmplitude,
                _initialAlphaAllocation,
                _initialOmegaAllocation
            )
        );

        require(_isValidSignature(message, _oracleSignature, _oracle), "LIQUIDATE: Invalid Trufin oracle signature");
    }

    // Could inline this if not reused
    function _getAlignment(
        Strategy storage _strategyOne,
        Strategy storage _strategyTwo
    ) internal view returns (bool aligned) {
        if (_strategyOne.alpha == _strategyTwo.alpha && _strategyOne.omega == _strategyTwo.omega) {
            aligned = true;
        } else if (_strategyOne.omega == _strategyTwo.alpha && _strategyOne.omega == _strategyTwo.alpha) {
            aligned = false;
        } else {
            revert("COMBINATION: Strategies are not shared between two parties");
        }
    }

    // *** UPDATE NONCE ***

    function validateOracleNonceUpdate(
        uint256 _oracleNonce,
        bytes calldata _oracleSignature,
        address _oracle
    ) external view {
        bytes memory encoding = abi.encodePacked(_oracleNonce);

        require(
            _isValidSignature(encoding, _oracleSignature, _oracle),
            "ORACLE NONCE UPDATE: Invalid Trufin oracle signature"
        );
    }

    // Hashes a message and returns it in EIP-191 format
    function _generateMessageHash(bytes memory message) internal pure returns (bytes32) {
        return ECDSA.toEthSignedMessageHash(keccak256(message));
    }

    // Checks if a message hash hash been signed by a specific address
    function _isValidSignature(bytes32 _hash, bytes memory _signature, address _signer) internal view returns (bool) {
        bool valid = SignatureChecker.isValidSignatureNow(_signer, _hash, _signature);

        return valid;
    }

    // Hashes a message and checks if it has been signed by a specific address
    function _isValidSignature(
        bytes memory _message,
        bytes memory _signature,
        address _signer
    ) internal view returns (bool) {
        bytes32 messageHash = _generateMessageHash(_message);

        return _isValidSignature(messageHash, _signature, _signer);
    }

    // function checkLiquidationSignature(
    //     LiquidationParams memory _liquidationParams,
    //     Strategy storage _strategy,
    //     bytes memory _liquidationSignature,
    //     address _web2Address
    // ) external view {
    //     // Perform encoding in two stages to avoid stack depth issues

    //     bytes memory liquidationEncoding = abi.encodePacked(
    //         _liquidationParams.collateralNonce,
    //         _liquidationParams.alphaCompensation,
    //         _liquidationParams.omegaCompensation,
    //         _liquidationParams.alphaFee,
    //         _liquidationParams.omegaFee,
    //         _liquidationParams.newAmplitude,
    //         _liquidationParams.newMaxNotional,
    //         _liquidationParams.initialAlphaAllocation,
    //         _liquidationParams.initialOmegaAllocation
    //     );

    //     bytes memory fullEncoding = abi.encodePacked(
    //         liquidationEncoding,
    //         _strategy.bra,
    //         _strategy.ket,
    //         _strategy.basis,
    //         _strategy.expiry,
    //         _strategy.amplitude,
    //         _strategy.phase
    //     );

    //     bytes32 messageHash = keccak256(fullEncoding);

    //     require(
    //         isValidSigner(messageHash, _liquidationSignature, _web2Address),
    //         "Liquidation signature incorrect"
    //     );
    // }
}
