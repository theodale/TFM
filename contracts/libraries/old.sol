// // SPDX-License-Identifier: GPL-3.0

// pragma solidity =0.8.14;

// import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
// // import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// import "../misc/Types.sol";

// import "hardhat/console.sol";

// /// @notice Contains signature-validating functionality utilised by the TFM
// library Validator {
//     function validateSpearmint(
//         MintTerms calldata _terms,
//         address _oracle,
//         SpearmintParameters calldata _parameters,
//         uint256 _mintNonce
//     ) external view {
//         bytes memory termsMessage = abi.encodePacked(
//             _terms.expiry,
//             _terms.alphaCollateralRequirement,
//             _terms.omegaCollateralRequirement,
//             _terms.alphaFee,
//             _terms.omegaFee,
//             _terms.oracleNonce,
//             _terms.bra,
//             _terms.ket,
//             _terms.basis,
//             _terms.amplitude,
//             _terms.phase
//         );

//         require(
//             _isValidSignature(termsMessage, _parameters.oracleSignature, _oracle),
//             "SPEARMINT: Invalid Trufin oracle signature"
//         );

//         bytes memory parametersMessage = abi.encodePacked(
//             _parameters.oracleSignature,
//             _parameters.alpha,
//             _parameters.omega,
//             _parameters.premium,
//             _parameters.transferable,
//             _mintNonce
//         );

//         bytes32 hash = _generateMessageHash(parametersMessage);

//         require(
//             _isValidSignature(hash, _parameters.alphaSignature, _parameters.alpha),
//             "SPEARMINT: Alpha signature invalid"
//         );

//         if (_parameters.alpha != _parameters.omega) {
//             require(
//                 _isValidSignature(hash, _parameters.omegaSignature, _parameters.omega),
//                 "SPEARMINT: Omega signature invalid"
//             );
//         }
//     }

//     // Hashes a message and returns it in EIP-191 format
//     function _generateMessageHash(bytes memory message) internal pure returns (bytes32) {
//         return ECDSA.toEthSignedMessageHash(keccak256(message));
//     }

//     // Checks if a message hash hash been signed by a specific address
//     function _isValidSignature(bytes32 _hash, bytes memory _signature, address _signer) internal view returns (bool) {
//         bool valid = SignatureChecker.isValidSignatureNow(_signer, _hash, _signature);

//         return valid;
//     }

//     // Hashes a message and checks if it has been signed by a specific address
//     function _isValidSignature(
//         bytes memory _message,
//         bytes memory _signature,
//         address _signer
//     ) internal view returns (bool) {
//         bytes32 messageHash = _generateMessageHash(_message);

//         return _isValidSignature(messageHash, _signature, _signer);
//     }

//     // function ensureTransferApprovals(
//     //     TransferParameters calldata _parameters,
//     //     Strategy storage _strategy,
//     //     address _sender,
//     //     bool alphaTransfer
//     // ) external view {
//     //     bytes memory message = abi.encodePacked(
//     //         _parameters.oracleSignature,
//     //         _parameters.strategyId,
//     //         _parameters.recipient,
//     //         _parameters.premium,
//     //         _strategy.actionNonce
//     //     );
//     //     bytes32 hash = _generateMessageHash(message);
//     //     require(_isValidSignature(hash, _parameters.senderSignature, _sender), "TRANSFER: Sender signature invalid");
//     //     require(
//     //         _isValidSignature(hash, _parameters.recipientSignature, _parameters.recipient),
//     //         "TRANSFER: Recipient signature invalid"
//     //     );
//     //     // Check non-transferring party's signature if strategy is not transferable
//     //     if (!_strategy.transferable) {
//     //         address staticParty = alphaTransfer ? _strategy.omega : _strategy.alpha;
//     //         require(
//     //             _isValidSignature(hash, _parameters.staticPartySignature, staticParty),
//     //             "TRANSFER: Static party signature invalid"
//     //         );
//     //     }
//     // }
//     // function validateTransferTerms(
//     //     TransferTerms calldata _terms,
//     //     Strategy storage _strategy,
//     //     address _oracle,
//     //     bytes memory _oracleSignature
//     // ) external view {
//     //     bytes memory message = abi.encodePacked(
//     //         _strategy.expiry,
//     //         _strategy.bra,
//     //         _strategy.ket,
//     //         _strategy.basis,
//     //         _strategy.amplitude,
//     //         _strategy.phase,
//     //         _terms.senderFee,
//     //         _terms.recipientFee,
//     //         _terms.recipientCollateralRequirement,
//     //         _terms.alphaTransfer,
//     //         _terms.oracleNonce
//     //     );
//     //     require(_isValidSignature(message, _oracleSignature, _oracle), "TRANSFER: Invalid Trufin oracle signature");
//     // }
//     // // COMBINATION
//     // function checkCombinationApprovals(
//     //     uint256 _strategyOneId,
//     //     uint256 _strategyTwoId,
//     //     Strategy storage _strategyOne,
//     //     Strategy storage _strategyTwo,
//     //     bytes calldata _strategyOneAlphaSignature,
//     //     bytes calldata _strategyOneOmegaSignature,
//     //     bytes calldata _oracleSignature
//     // ) external view {
//     //     bytes memory message = abi.encodePacked(
//     //         _strategyOneId,
//     //         _strategyTwoId,
//     //         _strategyOne.actionNonce,
//     //         _strategyTwo.actionNonce,
//     //         _oracleSignature
//     //     );
//     //     bytes32 hash = _generateMessageHash(message);
//     //     require(
//     //         _isValidSignature(hash, _strategyOneAlphaSignature, _strategyOne.alpha),
//     //         "COMBINATION: Invalid strategy two alpha signature"
//     //     );
//     //     require(
//     //         _isValidSignature(hash, _strategyOneOmegaSignature, _strategyOne.omega),
//     //         "COMBINATION: Invalid strategy one omega signature"
//     //     );
//     // }
//     // function validateCombinationTerms(
//     //     CombinationTerms calldata _terms,
//     //     Strategy storage _strategyOne,
//     //     Strategy storage _strategyTwo,
//     //     address _oracle,
//     //     bytes calldata _oracleSignature
//     // ) external view {
//     //     // Ensure alignment specified by terms is accurate
//     //     if (_terms.aligned) {
//     //         require(
//     //             _strategyOne.alpha == _strategyTwo.alpha && _strategyOne.omega == _strategyTwo.omega,
//     //             "COMBINATION: Strategies are not aligned"
//     //         );
//     //     } else {
//     //         require(
//     //             _strategyOne.omega == _strategyTwo.alpha && _strategyOne.omega == _strategyTwo.alpha,
//     //             "COMBINATION: Strategies are not aligned"
//     //         );
//     //     }
//     //     // Investigate security risk with two phases in message => should be ok if not next to each other?
//     //     bytes memory message = abi.encodePacked(
//     //         abi.encodePacked(
//     //             _strategyOne.expiry,
//     //             _strategyOne.bra,
//     //             _strategyOne.ket,
//     //             _strategyOne.basis,
//     //             _strategyOne.amplitude,
//     //             _strategyOne.phase,
//     //             _strategyTwo.expiry,
//     //             _strategyTwo.bra,
//     //             _strategyTwo.ket,
//     //             _strategyTwo.basis
//     //         ),
//     //         abi.encodePacked(
//     //             _strategyTwo.amplitude,
//     //             _strategyTwo.phase,
//     //             _terms.strategyOneAlphaFee,
//     //             _terms.strategyOneOmegaFee,
//     //             _terms.resultingAlphaCollateralRequirement,
//     //             _terms.resultingOmegaCollateralRequirement,
//     //             _terms.resultingPhase
//     //         ),
//     //         abi.encodePacked(_terms.resultingAmplitude, _terms.oracleNonce, _terms.aligned)
//     //     );
//     //     require(_isValidSignature(message, _oracleSignature, _oracle), "COMBINATION: Invalid Trufin oracle signature");
//     // }
//     // // NOVATE
//     // function validateNovationTerms(
//     //     NovationTerms calldata _terms,
//     //     Strategy storage _strategyOne,
//     //     Strategy storage _strategyTwo,
//     //     address _oracle,
//     //     bytes calldata _oracleSignature
//     // ) external view {
//     //     bytes memory message = abi.encodePacked(
//     //         abi.encodePacked(
//     //             _strategyOne.expiry,
//     //             _strategyOne.bra,
//     //             _strategyOne.ket,
//     //             _strategyOne.basis,
//     //             _strategyOne.amplitude,
//     //             _strategyOne.phase,
//     //             _strategyTwo.expiry,
//     //             _strategyTwo.bra,
//     //             _strategyTwo.ket,
//     //             _strategyTwo.basis
//     //         ),
//     //         abi.encodePacked(
//     //             _strategyTwo.amplitude,
//     //             _strategyTwo.phase,
//     //             _terms.strategyOneResultingAlphaCollateralRequirement,
//     //             _terms.strategyOneResultingOmegaCollateralRequirement,
//     //             _terms.strategyTwoResultingAlphaCollateralRequirement,
//     //             _terms.strategyTwoResultingOmegaCollateralRequirement
//     //         ),
//     //         abi.encodePacked(
//     //             _terms.strategyOneResultingAmplitude,
//     //             _terms.strategyTwoResultingAmplitude,
//     //             _terms.fee,
//     //             _terms.oracleNonce
//     //         )
//     //     );
//     //     require(_isValidSignature(message, _oracleSignature, _oracle), "NOVATION: Invalid Trufin oracle signature");
//     // }
//     // function checkNovationApprovals(
//     //     NovationParameters calldata _parameters,
//     //     Strategy storage _strategyOne,
//     //     Strategy storage _strategyTwo
//     // ) external view {
//     //     // Do we need action nonce here?
//     //     bytes memory message = abi.encodePacked(
//     //         _parameters.strategyOneId,
//     //         _parameters.strategyTwoId,
//     //         _strategyOne.actionNonce,
//     //         _strategyTwo.actionNonce,
//     //         _parameters.oracleSignature
//     //     );
//     //     bytes32 hash = _generateMessageHash(message);
//     //     require(
//     //         _isValidSignature(hash, _parameters.middlePartySignature, _strategyOne.omega),
//     //         "NOVATION: Invalid strategy two alpha signature"
//     //     );
//     //     if (!_strategyOne.transferable) {
//     //         require(
//     //             _isValidSignature(hash, _parameters.strategyOneNonMiddlePartySignature, _strategyOne.alpha),
//     //             "NOVATION: Invalid strategy one omega signature"
//     //         );
//     //     }
//     //     if (!_strategyTwo.transferable) {
//     //         require(
//     //             _isValidSignature(hash, _parameters.strategyTwoNonMiddlePartySignature, _strategyTwo.omega),
//     //             "NOVATION: Invalid strategy one omega signature"
//     //         );
//     //     }
//     // }
//     // // EXERCISE
//     // function validateExerciseTerms(
//     //     ExerciseTerms calldata _terms,
//     //     Strategy storage _strategy,
//     //     address _oracle,
//     //     bytes calldata _oracleSignature
//     // ) external view {
//     //     bytes memory message = abi.encodePacked(
//     //         _strategy.expiry,
//     //         _strategy.bra,
//     //         _strategy.ket,
//     //         _strategy.basis,
//     //         _strategy.amplitude,
//     //         _strategy.phase,
//     //         _terms.oracleNonce,
//     //         _terms.payout
//     //     );
//     //     require(_isValidSignature(message, _oracleSignature, _oracle), "EXERCISE: Invalid Trufin oracle signature");
//     // }
//     // // LIQUIDATE
//     // function validateLiquidationTerms(
//     //     LiquidationTerms calldata _terms,
//     //     Strategy storage _strategy,
//     //     bytes calldata _oracleSignature,
//     //     address _oracle,
//     //     uint256 _initialAlphaAllocation,
//     //     uint256 _initialOmegaAllocation
//     // ) external view {
//     //     bytes memory message = abi.encodePacked(
//     //         abi.encodePacked(
//     //             _strategy.expiry,
//     //             _strategy.bra,
//     //             _strategy.ket,
//     //             _strategy.basis,
//     //             _strategy.amplitude,
//     //             _strategy.phase,
//     //             _terms.oracleNonce,
//     //             _terms.compensation,
//     //             _terms.alphaPenalisation
//     //         ),
//     //         abi.encodePacked(
//     //             _terms.omegaPenalisation,
//     //             _terms.postLiquidationAmplitude,
//     //             _initialAlphaAllocation,
//     //             _initialOmegaAllocation
//     //         )
//     //     );
//     //     require(_isValidSignature(message, _oracleSignature, _oracle), "LIQUIDATION: Invalid Trufin oracle signature");
//     // }
//     // // *** UPDATE NONCE ***
//     // function validateOracleNonceUpdate(
//     //     uint256 _oracleNonce,
//     //     bytes calldata _oracleSignature,
//     //     address _oracle
//     // ) external view {
//     //     bytes memory encoding = abi.encodePacked(_oracleNonce);
//     //     require(
//     //         _isValidSignature(encoding, _oracleSignature, _oracle),
//     //         "ORACLE NONCE UPDATE: Invalid Trufin oracle signature"
//     //     );
//     // }
// }

// // TO DO:
// // - Ensure no signature replay across actions - do we need enum?
// // - Check if use of encodePacked is safe
// // - Neaten and minify used of ECDSA -> make one function that prefixes and one that doesn't -> maybe also make a straight prefix function
