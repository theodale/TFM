// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../misc/Types.sol";

import "hardhat/console.sol";

// TO DO:
// - Ensure no signature replay across actions - do we need enum?
// - Check if use of encodePacked is safe

library Utils {
    // SPEARMINT

    // Checks that alpha and omega have provided signatures to authorise the spearmint
    function ensureSpearmintApprovals(
        SpearmintParameters calldata _parameters,
        uint256 _mintNonce
    ) external view {
        bytes32 message = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    _parameters.oracleSignature,
                    _parameters.alpha,
                    _parameters.omega,
                    _parameters.premium,
                    _parameters.transferable,
                    _mintNonce,
                    Action.MINT
                )
            )
        );

        require(
            _isValidSignature(
                message,
                _parameters.alphaSignature,
                _parameters.alpha
            ),
            "Alpha signature invalid"
        );

        require(
            _isValidSignature(
                message,
                _parameters.omegaSignature,
                _parameters.omega
            ),
            "Omega signature invalid"
        );
    }

    function validateSpearmintTerms(
        SpearmintTerms calldata _terms,
        bytes calldata _oracleSignature,
        address _oracle
    ) external view {
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
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
                )
            )
        );

        require(
            _isValidSignature(messageHash, _oracleSignature, _oracle),
            "TFM: Invalid Trufin oracle signature"
        );
    }

    function ensureTransferApprovals(
        TransferParameters calldata _parameters,
        Strategy storage _strategy,
        address _sender,
        bool alphaTransfer
    ) external view {
        bytes32 message = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    _parameters.oracleSignature,
                    _parameters.strategyId,
                    _parameters.recipient,
                    _parameters.premium,
                    Action.TRANSFER
                )
            )
        );

        require(
            _isValidSignature(message, _parameters.senderSignature, _sender),
            "Sender signature invalid"
        );

        require(
            _isValidSignature(
                message,
                _parameters.recipientSignature,
                _parameters.recipient
            ),
            "Recipient signature invalid"
        );

        // Check non-transferring party's signature if strategy is not transferable
        if (!_strategy.transferable) {
            address staticParty = alphaTransfer
                ? _strategy.omega
                : _strategy.alpha;

            require(
                _isValidSignature(
                    message,
                    _parameters.staticPartySignature,
                    staticParty
                ),
                "Static party signature invalid"
            );
        }
    }

    function validateTransferTerms(
        TransferTerms calldata _terms,
        Strategy storage _strategy,
        address _trufinOracle,
        bytes memory _trufinOracleSignature
    ) external view {
        bytes32 messageHash = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
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
                )
            )
        );

        require(
            _isValidSignature(
                messageHash,
                _trufinOracleSignature,
                _trufinOracle
            ),
            "TFM: Invalid Trufin oracle signature"
        );
    }

    // Converts base message hash into EIP-191 format and checks whether it has been signed by an address
    function _isValidSignature(
        bytes32 _messageHash,
        bytes memory _signature,
        address _signer
    ) internal view returns (bool) {
        bool valid = SignatureChecker.isValidSignatureNow(
            _signer,
            _messageHash,
            _signature
        );

        return valid;
    }

    // // TRANSFER

    // function checkTransferApprovals(
    //     TransferParameters memory _transferParameters,
    //     Strategy storage _strategy,
    //     bytes[] memory _signatures
    // ) external view {
    //     bytes32 messageHash = keccak256(
    //         abi.encodePacked(
    //             _transferParameters.strategyId,
    //             _transferParameters.alphaTransfer,
    //             _transferParameters.recipient,
    //             _transferParameters.premium,
    //             _strategy.actionNonce
    //         )
    //     );
    // }

    // function checkTransferDataPackage(
    //     TransferDataPackage memory _transferDataPackage,
    //     Strategy storage _strategy,
    //     address _trufinOracle,
    //     bytes memory _trufinOracleSignature
    // ) external view {
    //     bytes32 messageHash = keccak256(
    //         abi.encodePacked(
    //             _strategy.expiry,
    //             _strategy.bra,
    //             _strategy.ket,
    //             _strategy.basis,
    //             _strategy.amplitude,
    //             _strategy.phase,
    //           _terms.senderFee,
    //           _terms.recipientFee,
    //           _terms.alphaCollateralRequirement,
    //           _terms.omegaCollateralRequirement,
    //           _terms.oracleNonce
    //         )
    //     );

    //     require(
    //         _isValidSignature(
    //             messageHash,
    //             _trufinOracleSignature,
    //             _trufinOracle
    //         ),
    //         "TFM: Invalid Trufin oracle signature"
    //     );
    // }

    // /**
    //  * @notice check collateral requirements web2-signature but also some signature component can be taken from strategy
    //  * @param _collateralParams collateral requirements which are signed by web2
    //  * @param _strategy strategy which are connected with _collateralParams
    //  * @param _sigWeb2 web2 signature of collateral requirements
    //  * @param _web2Address address of web2
    //  * @param _onlyCollateralParams construct message with using only _collateralParams
    //  */
    // function checkWeb2Signature(
    //     CollateralParamsFull memory _collateralParams,
    //     Strategy storage _strategy,
    //     bytes memory _sigWeb2,
    //     uint256 _collateralNonce,
    //     address _web2Address,
    //     bool _onlyCollateralParams
    // ) public view {
    //     //check collateralNonce is correct
    //     require(
    //         (_collateralNonce >= _collateralParams.collateralNonce) &&
    //             (_collateralNonce - _collateralParams.collateralNonce <= 1),
    //         "C31"
    //     ); // "errors with collateral requirement"
    //     //Msg that should be signed with SignatureWeb2
    //     require(isValidSigner(keccak256(
    //         _onlyCollateralParams
    //             ? abiEncodeCollateralParams(_collateralParams)
    //             : abiEncodeMix(_collateralParams, _strategy)
    //             ), _sigWeb2, _web2Address), "A28"); //Not signed by Web2 Collateral Manager
    // }

    // function abiEncodeMix(CollateralParamsFull memory _collateralParams, Strategy storage _strategy) private view returns(bytes memory) {
    //     return abi.encode(
    //                 _strategy.expiry,
    //                 _collateralParams.alphaCollateralRequirement,
    //                 _collateralParams.omegaCollateralRequirement,
    //                 _collateralParams.collateralNonce,
    //                 _strategy.bra,
    //                 _strategy.ket,
    //                 _strategy.basis,
    //                 _strategy.amplitude,
    //                 _strategy.maxNotional,
    //                 _strategy.phase);
    // }

    // function abiEncodeCollateralParams(CollateralParamsFull memory _collateralParams) private pure returns(bytes memory) {
    //     return abi.encode(
    //                 _collateralParams.expiry,
    //                 _collateralParams.alphaCollateralRequirement,
    //                 _collateralParams.omegaCollateralRequirement,
    //                 _collateralParams.collateralNonce,
    //                 _collateralParams.bra,
    //                 _collateralParams.ket,
    //                 _collateralParams.basis,
    //                 _collateralParams.amplitude,
    //                 _collateralParams.maxNotional,
    //                 _collateralParams.phase
    //             );
    // }

    // /**
    //  * @notice check nonce web2-signature
    //  *
    //  * @param _collateralNonce nonce to check
    //  * @param _sigWeb2 web2 signature of collateral requirements
    //  * @param _web2Address address of web2
    //  */
    // function checkWebSignatureForNonce(
    //     bytes calldata _sigWeb2,
    //     uint256 _collateralNonce,
    //     address _web2Address
    // ) external view {
    //     bytes32 msgHash = keccak256(abi.encode(_collateralNonce));
    //     require(isValidSigner(msgHash, _sigWeb2, _web2Address), "A28"); //Not signed by Web2 Collateral Manager
    // }

    // /**
    //  * @notice check nonce that expired web2-signature
    //  * @param _sigWeb2 web2 signature of collateral requirements
    //  * @param _web2Address address of web2
    //  * @param _paramsNonce nonce to check
    //  * @param _expiry expiry timestamp
    //  */
    // function checkWeb2SignatureForExpiry(
    //     bytes memory _sigWeb2,
    //     address _web2Address,
    //     uint256 _paramsNonce,
    //     uint256 _expiry
    // ) public view {
    //     //Msg that should be signed with SignatureWeb2
    //     bytes32 msgHash = keccak256(abi.encode(_expiry, _paramsNonce, true));

    //     require(isValidSigner(msgHash, _sigWeb2, _web2Address), "S1"); // Strategy is expired
    // }

    // /**
    //  * @notice check payout web2-signature for exercise
    //  * @param _collateralParams collateral requirements (payout) for exercise
    //  * @param _sigWeb2 web2 signature of collateral requirements
    //  * @param _web2Address address of web2
    //  */
    // function checkWeb2SignatureForPayout(
    //     CollateralParamsFull calldata _collateralParams,
    //     bytes calldata _sigWeb2,
    //     address _web2Address
    // ) external view {
    //     //Msg that should be signed with SignatureWeb2
    //     bytes32 msgHash = keccak256(
    //         abi.encode(
    //             _collateralParams.expiry,
    //             _collateralParams.alphaCollateralRequirement,
    //             _collateralParams.omegaCollateralRequirement,
    //             _collateralParams.collateralNonce,
    //             _collateralParams.bra,
    //             _collateralParams.ket,
    //             _collateralParams.basis,
    //             _collateralParams.amplitude,
    //             _collateralParams.maxNotional,
    //             _collateralParams.phase,
    //             "exercise"
    //         )
    //     );
    //     require(isValidSigner(msgHash, _sigWeb2, _web2Address), "A28"); //Not signed by Web2 Collateral Manager
    // }

    // /************************************************
    //  *  Cryptographic Novation Verification
    //  ***********************************************/

    // /**
    //     @notice Cryptography util fn returns whether the signature produced in signing a hash was signed
    //     by the private key corresponding to the inputted public address
    //     @param _params struct containing the parameters (thisStrategyID, targetStrategyID, actionCount1, actionCount2, timestamp)
    //     @param _thisStrategy data of the first strategy
    //     @param _targetStrategy data of the second strategy
    //     @param _thisStrategyNonce nonce for thisStrategy i.e., first strategy
    //     @param _targetStrategyNonce nonce for tarstrategies i.e., second strategy
    //     @param _collateralNonce actual collateral nonce
    // */
    // function checkNovationSignatures(
    //     NovateParams calldata _params,
    //     Strategy calldata _thisStrategy,
    //     Strategy calldata _targetStrategy,
    //     address _initiator,
    //     uint256 _thisStrategyNonce,
    //     uint256 _targetStrategyNonce,
    //     uint256 _collateralNonce
    // ) external view {
    //     bool _thisStrategyTransferable = _thisStrategy.transferable;
    //     bool _targetStrategyTransferable = _targetStrategy.transferable;

    //     address _thisStrategyNotInitiator = (_initiator == _thisStrategy.alpha)
    //         ? _thisStrategy.omega
    //         : _thisStrategy.alpha;
    //     address _targetStrategyNotInitiator = (_initiator ==
    //         _targetStrategy.alpha)
    //         ? _targetStrategy.omega
    //         : _targetStrategy.alpha;

    //     require(
    //         (_collateralNonce >= _params.collateralNonce) &&
    //             (_collateralNonce - _params.collateralNonce <= 1),
    //         "A26" // "Signature is expired"
    //     );

    //     bytes32 calculatedHash = keccak256(
    //         abi.encode(
    //             _params.thisStrategyID,
    //             _params.targetStrategyID,
    //             _thisStrategyNonce,
    //             _targetStrategyNonce,
    //             _params.collateralNonce,
    //             "novate"
    //         )
    //     );

    //     // Case 1 (Mandatory): Needed signature from initiator
    //     require(isValidSigner(calculatedHash, _params.sig1, _initiator), "A29"); // "Not signed by the initiator or person who is in the middle of the two strategies"
    //     // Case 2:
    //     //  If strategy1 is transferable and strategy2 isn't we only need signature from middle person and second strategy alpha
    //     if (_thisStrategyTransferable && !_targetStrategyTransferable) {
    //         require(
    //             isValidSigner(
    //                 calculatedHash,
    //                 _params.sig3,
    //                 _targetStrategyNotInitiator
    //             ),
    //             "A29-a"
    //         ); // Signature needed from target strategy alpha
    //     }
    //     // Case 3: If strategy1 is non-transferable and strategy2 is then we only need signature from middle person and first strategy omega
    //     else if (!_thisStrategyTransferable && _targetStrategyTransferable) {
    //         require(
    //             isValidSigner(
    //                 calculatedHash,
    //                 _params.sig2,
    //                 _thisStrategyNotInitiator
    //             ),
    //             "A29-b"
    //         ); // Signature needed from this strategy omega
    //     }
    //     // Case 4: If both strategies are non-transferable we need everybody's signature
    //     else if (!_thisStrategyTransferable && !_targetStrategyTransferable) {
    //         require(
    //             isValidSigner(
    //                 calculatedHash,
    //                 _params.sig2,
    //                 _thisStrategyNotInitiator
    //             ) &&
    //                 isValidSigner(
    //                     calculatedHash,
    //                     _params.sig3,
    //                     _targetStrategyNotInitiator
    //                 ),
    //             "A29-c" // "Signature needed by this strategy omega and target strategy alpha"
    //         );
    //     }
    // }

    // /**
    //     @notice Cryptography util fn returns whether the signature produced for combine in signing a hash was signed
    //     by the private key corresponding to the web2 address
    //     @param _params struct containing the parameters (thisStrategyID, targetStrategyID, actionCount1, actionCount2, timestamp)
    //     @param _alpha side
    //     @param _omega side
    //     @param _thisStrategyNonce nonce for thisStrategy i.e., first strategy
    //     @param _targetStrategyNonce nonce for tarstrategies i.e., second strategy
    //     @param _collateralNonce actual collateral nonce
    //     @param _targetAlpha target alpha side
    //     @param _targetOmega target omega side
    // */
    // function checkCombineSignatures(
    //     CombineParams calldata _params,
    //     address _alpha,
    //     address _omega,
    //     uint256 _thisStrategyNonce,
    //     uint256 _targetStrategyNonce,
    //     uint256 _collateralNonce,
    //     address _targetAlpha,
    //     address _targetOmega
    // ) external view {
    //     require(
    //         (_alpha == _targetAlpha && _omega == _targetOmega) ||
    //             (_alpha == _targetOmega && _omega == _targetAlpha),
    //         "S34" // "strategies not shared between two parties"
    //     );

    //     //check less than 2 epoch has passed since first signature

    //     require(
    //         (_collateralNonce >= _params.collateralNonce) &&
    //             (_collateralNonce - _params.collateralNonce <= 1),
    //         "A26"
    //     ); //Signature is expired

    //     //Msg that should be signed with Signature2
    //     bytes32 msgHash = keccak256(
    //         abi.encode(
    //             _params.thisStrategyID,
    //             _params.targetStrategyID,
    //             _thisStrategyNonce,
    //             _targetStrategyNonce,
    //             _params.collateralNonce,
    //             "combine"
    //         )
    //     );

    //     bool isAlpha = isValidSigner(msgHash, _params.sig2, _alpha);
    //     require(isAlpha || isValidSigner(msgHash, _params.sig2, _omega), "A23"); //Signature2 not signed by alpha or by omega

    //     if (isAlpha) {
    //         require(isValidSigner(msgHash, _params.sig1, _omega), "A24"); //Signature2 signed by alpha, Signature1 not signed by omega
    //     } else {
    //         require(isValidSigner(msgHash, _params.sig1, _alpha), "A25"); //Signature2 signed by omega, Signature1 not signed by alpha
    //     }
    // }

    // /**
    //     @notice Cryptography util fn returns whether the signature produced for spearmint in signing a hash was signed
    //     by the private key corresponding alpha and omega
    //     @param _params struct containing the parameters (thisStrategyID, targetStrategyID, actionCount1, actionCount2, timestamp)
    //     @param _pairNonce alpha + omega pair nonce
    // */
    // function checkSpearmintUserSignatures(
    //     SpearmintParams calldata _params,
    //     uint256 _pairNonce
    // ) external view {
    //     //Msg that should be signed with Signature2
    //     bytes32 msgHash = keccak256(
    //         abi.encode(
    //             _params.alpha,
    //             _params.omega,
    //             _params.transferable,
    //             _params.premium,
    //             _pairNonce,
    //             _params.sigWeb2,
    //             "spearmint"
    //         )
    //     );

    //     bool isAlpha = isValidSigner(msgHash, _params.sig2, _params.alpha);
    //     require(
    //         isAlpha || isValidSigner(msgHash, _params.sig2, _params.omega),
    //         "A23"
    //     ); //Signature2 not signed by alpha or by omega

    //     if (isAlpha) {
    //         require(isValidSigner(msgHash, _params.sig1, _params.omega), "A24"); //Signature2 signed by alpha, Signature1 not signed by omega
    //     } else {
    //         require(isValidSigner(msgHash, _params.sig1, _params.alpha), "A25"); //Signature2 signed by omega, Signature1 not signed by alpha
    //     }
    // }

    // /**
    //     @notice Cryptography util fn returns whether the signature produced for transfer in signing a hash was signed
    //     by the private key corresponding alpha and omega
    //     @param _params struct containing the parameters (thisStrategyID, targetStrategyID, actionCount1, actionCount2, timestamp)
    //     @param _alpha side
    //     @param _omega side
    //     @param _strategyNonce nonce of strategy
    //     @param _transferable is strategy transferable?
    //     @param _expiry strategy expiration timestamp
    // */
    // function checkTransferUserSignaturesAndParams(
    //     TransferParams calldata _params,
    //     address _alpha,
    //     address _omega,
    //     uint256 _strategyNonce,
    //     bool _transferable,
    //     uint256 _expiry
    // ) external view {
    //     //slither-disable-next-line timestamp
    //     require(_expiry > block.timestamp, "S1"); // "strategy must be active"
    //     require(_params.strategyNonce == _strategyNonce, "A27"); //Strategy Nonce invalid

    //     // alpha / omega signs message that yes i want to transfer my position to target - sig1
    //     // target signs message that yes i agree to enter the position - sig2 using sig1
    //     // omega / alpha signs that they agree to the position. - sig3 using sig1

    //     bytes32 msgHash = keccak256(
    //         abi.encode(
    //             _params.thisStrategyID,
    //             _params.targetUser,
    //             _strategyNonce,
    //             _params.premium,
    //             _params.alphaTransfer,
    //             _params.sigWeb2,
    //             "transfer"
    //         )
    //     );

    //     bool isAlpha = isValidSigner(msgHash, _params.sig1, _alpha);
    //     require(isAlpha || isValidSigner(msgHash, _params.sig1, _omega), "A23"); //Signature not signed by alpha or by omega

    //     require(
    //         isValidSigner(msgHash, _params.sig2, _params.targetUser),
    //         "A30"
    //     );

    //     if (_transferable) {
    //         return;
    //     }

    //     if (isAlpha) {
    //         require(isValidSigner(msgHash, _params.sig3, _omega), "A24");
    //     } else {
    //         require(isValidSigner(msgHash, _params.sig3, _alpha), "A25");
    //     }
    // }

    // /**
    //     @notice checks if two strategies are compatible in terms of basis and expiry
    //     and that they are not expired.
    //     @param _thisStrategy the ID of one of the strategies to compare
    //     @param _targetStrategy the ID of the other strategy to compare against
    //     @param _collateralNonce actual collateral nonce
    //     @param _web2Address address of web2 signer
    // */
    // function strategiesCompatible(
    //     bytes calldata _sigWeb2,
    //     Strategy calldata _thisStrategy,
    //     Strategy calldata _targetStrategy,
    //     uint256 _collateralNonce,
    //     address _web2Address
    // ) external view {
    //     require(
    //         _thisStrategy.bra == _targetStrategy.bra &&
    //             _thisStrategy.ket == _targetStrategy.ket &&
    //             _thisStrategy.basis == _targetStrategy.basis,
    //         "S33" // "strategies must have the same bra, ket, and basis"
    //     );

    //     /// @review move to library
    //     require(
    //         _thisStrategy.expiry == _targetStrategy.expiry,
    //         "S32" // "strategies must share the same expiry"
    //     );
    //     {
    //         checkWeb2SignatureForExpiry(
    //             _sigWeb2,
    //             _web2Address,
    //             _collateralNonce,
    //             _thisStrategy.expiry
    //         );
    //     }
    // }

    // /**
    //     @notice Function to check collateral requirements are valid, i.e.: they are signed by the web2 backend &
    //     the parameters were not modified by the user & the data is up-to-date (through the Collateral Manager).
    //     @dev The collateral information only specifies strategyID, and the parameters are read from storage to ensure
    //     that they have not been updated on chain.
    //     @param _paramsID struct containing the parameters (strategyID, collateral requirements, collateralNonce)
    //     @param _signature web2 signature of hashed message
    //     @param _strategy strategy data for which collateral requirements will be checked
    //     @param _collateralNonce actual collateral nonce
    //     @param _web2Address web2 address of signer
    // */
    // function checkCollateralRequirements(
    //     CollateralParamsID calldata _paramsID,
    //     bytes calldata _signature,
    //     Strategy storage _strategy,
    //     uint256 _collateralNonce,
    //     address _web2Address
    // ) external view {
    //     // Read strategy params from storage to ensure that collateral
    //     // information from web2 should still be valid.
    //     CollateralParamsFull memory collateralParams = CollateralParamsFull(
    //         _strategy.expiry,
    //         _paramsID.alphaCollateralRequirement,
    //         _paramsID.omegaCollateralRequirement,
    //         _paramsID.collateralNonce,
    //         _strategy.bra,
    //         _strategy.ket,
    //         _strategy.basis,
    //         _strategy.amplitude,
    //         _strategy.maxNotional,
    //         _strategy.phase
    //     );

    //     checkWeb2Signature(
    //         collateralParams,
    //         _strategy,
    //         _signature,
    //         _collateralNonce,
    //         _web2Address,
    //         false
    //     );
    // }

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
