// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import "../interfaces/ITrufinWallet.sol";
import "../misc/Types.sol";

import "hardhat/console.sol";

/// @notice Contains signature-validating functionality utilised by the TFM
library Validator {
    function approveSpearmint(
        SpearmintParameters calldata _parameters,
        address _oracle,
        uint256 _mintNonce
    ) external view {
        bytes memory oracleMessage = abi.encodePacked(
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
            _parameters.phase
        );

        require(
            _isValidSignature(oracleMessage, _parameters.oracleSignature, _oracle),
            "SPEARMINT: Invalid Trufin oracle signature"
        );

        bytes memory spearminterMessage = abi.encodePacked(
            _parameters.oracleSignature,
            _parameters.alpha,
            _parameters.omega,
            _parameters.premium,
            _parameters.transferable,
            _mintNonce
        );

        bytes32 hash = _generateMessageHash(spearminterMessage);

        require(
            _isValidSignature(hash, _parameters.alphaSignature, _parameters.alpha),
            "SPEARMINT: Alpha signature invalid"
        );

        if (_parameters.alpha != _parameters.omega) {
            require(
                _isValidSignature(hash, _parameters.omegaSignature, _parameters.omega),
                "SPEARMINT: Omega signature invalid"
            );
        }
    }

    function approvePeppermint(ApprovePeppermintParameters calldata _parameters) external view {
        bytes memory message = abi.encodePacked(
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
            _parameters.phase
        );

        require(
            _isValidSignature(message, _parameters.oracleSignature, _parameters.oracle),
            "SPEARMINT: Invalid Trufin oracle signature"
        );
    }

    function approveTransfer(
        TransferParameters calldata _parameters,
        Strategy storage _strategy,
        address _sender,
        address _oracle
    ) external view {
        bytes memory transfererMessage = abi.encodePacked(
            _parameters.oracleSignature,
            _parameters.strategyId,
            _parameters.recipient,
            _parameters.premium,
            _strategy.actionNonce
        );

        bytes32 hash = _generateMessageHash(transfererMessage);

        require(_isValidSignature(hash, _parameters.senderSignature, _sender), "TRANSFER: Sender signature invalid");
        require(
            _isValidSignature(hash, _parameters.recipientSignature, _parameters.recipient),
            "TRANSFER: Recipient signature invalid"
        );

        // Check non-transferring party's signature if strategy is not transferable
        if (!_strategy.transferable) {
            address staticParty = _parameters.alphaTransfer ? _strategy.omega : _strategy.alpha;

            require(
                _isValidSignature(hash, _parameters.staticPartySignature, staticParty),
                "TRANSFER: Static party signature invalid"
            );
        }

        bytes memory oracleMessage = abi.encodePacked(
            abi.encodePacked(
                _strategy.expiry,
                _strategy.bra,
                _strategy.ket,
                _strategy.basis,
                _strategy.amplitude,
                _strategy.phase,
                _parameters.senderFee,
                _parameters.recipientFee,
                _parameters.recipientCollateralRequirement,
                _parameters.alphaTransfer
            ),
            _parameters.oracleNonce
        );

        require(
            _isValidSignature(oracleMessage, _parameters.oracleSignature, _oracle),
            "TRANSFER: Invalid Trufin oracle signature"
        );
    }

    function approveCombination(
        CombinationParameters calldata _parameters,
        Strategy storage _strategyOne,
        Strategy storage _strategyTwo,
        address _oracle
    ) external view {
        bytes memory combinerMessage = abi.encodePacked(
            _parameters.strategyOneId,
            _parameters.strategyTwoId,
            _strategyOne.actionNonce,
            _strategyTwo.actionNonce,
            _parameters.oracleSignature
        );

        bytes32 hash = _generateMessageHash(combinerMessage);

        require(
            _isValidSignature(hash, _parameters.alphaOneSignature, _strategyOne.alpha),
            "COMBINATION: Invalid strategy two alpha signature"
        );
        require(
            _isValidSignature(hash, _parameters.omegaOneSignature, _strategyOne.omega),
            "COMBINATION: Invalid strategy one omega signature"
        );

        // Ensure aligment specified in parameters applies to strategy pair
        if (_parameters.aligned) {
            require(
                _strategyOne.alpha == _strategyTwo.alpha && _strategyOne.omega == _strategyTwo.omega,
                "COMBINATION: Strategies are not aligned"
            );
        } else {
            require(
                _strategyOne.alpha == _strategyTwo.omega && _strategyOne.omega == _strategyTwo.alpha,
                "COMBINATION: Strategies are not aligned"
            );
        }

        // Investigate security risk with two phases in message => should be ok if not next to each other?
        bytes memory oracleMessage = abi.encodePacked(
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
                _parameters.strategyOneAlphaFee,
                _parameters.strategyOneOmegaFee,
                _parameters.resultingAlphaCollateralRequirement,
                _parameters.resultingOmegaCollateralRequirement,
                _parameters.resultingPhase
            ),
            abi.encodePacked(_parameters.resultingAmplitude, _parameters.oracleNonce, _parameters.aligned)
        );

        require(
            _isValidSignature(oracleMessage, _parameters.oracleSignature, _oracle),
            "COMBINATION: Invalid Trufin oracle signature"
        );
    }

    function approveExercise(
        int256 _payout,
        uint256 _oracleNonce,
        bytes calldata _oracleSignature,
        Strategy storage _strategy,
        address _oracle
    ) external view {
        bytes memory message = abi.encodePacked(
            _strategy.expiry,
            _strategy.bra,
            _strategy.ket,
            _strategy.basis,
            _strategy.amplitude,
            _strategy.phase,
            _oracleNonce,
            _payout
        );

        require(_isValidSignature(message, _oracleSignature, _oracle), "EXERCISE: Invalid Trufin oracle signature");
    }

    function approveLiquidation(
        ApproveLiquidationParameters calldata _parameters,
        Strategy storage _strategy
    ) external view {
        bytes memory message = abi.encodePacked(
            abi.encodePacked(
                _strategy.expiry,
                _strategy.bra,
                _strategy.ket,
                _strategy.basis,
                _strategy.amplitude,
                _strategy.phase,
                _parameters.oracleNonce,
                _parameters.compensation,
                _parameters.alphaPenalisation
            ),
            abi.encodePacked(
                _parameters.omegaPenalisation,
                _parameters.postLiquidationAmplitude,
                _parameters.alphaInitialCollateral,
                _parameters.omegaInitialCollateral
            )
        );

        require(
            _isValidSignature(message, _parameters.oracleSignature, _parameters.oracle),
            "LIQUIDATION: Invalid Trufin oracle signature"
        );
    }

    // Transfers ERC20 tokens from a user's wallet to a recipient address
    function _transferFromWallet(
        mapping(address => ITrufinWallet) storage _wallets,
        address _token,
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal {
        _wallets[_sender].transferERC20(_token, address(_wallets[_recipient]), _amount);
    }

    function _transferFromWalletTwice(
        mapping(address => ITrufinWallet) storage _wallets,
        address _sender,
        address _basis,
        address _recipientOne,
        uint256 _amountOne,
        address _recipientTwo,
        uint256 _amountTwo
    ) internal {
        _wallets[_sender].transferERC20Twice(_basis, _recipientOne, _amountOne, _recipientTwo, _amountTwo);
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
}
