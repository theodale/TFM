// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

// *** STATE ***

struct Strategy {
    bool transferable;
    address bra;
    address ket;
    address basis;
    address alpha;
    address omega;
    uint256 expiry;
    int256 amplitude;
    int256[2][] phase;
    // Prevents replay of strategy action meta-transactions
    uint256 actionNonce;
}

// *** ACTIONS ***

// SPEARMINT

struct SpearmintTerms {
    uint256 expiry;
    uint256 alphaCollateralRequirement;
    uint256 omegaCollateralRequirement;
    uint256 alphaFee;
    uint256 omegaFee;
    uint256 oracleNonce;
    address bra;
    address ket;
    address basis;
    int256 amplitude;
    int256[2][] phase;
}

struct SpearmintParameters {
    // Links to a specific set of spearmint terms
    bytes oracleSignature;
    address alpha;
    bytes alphaSignature;
    address omega;
    bytes omegaSignature;
    int256 premium;
    bool transferable;
}

// TRANSFER

struct TransferTerms {
    uint256 recipientCollateralRequirement;
    uint256 oracleNonce;
    uint256 senderFee;
    uint256 recipientFee;
    bool alphaTransfer;
}

struct TransferParameters {
    uint256 strategyId;
    address recipient;
    // If premium is +ve/-ve => sender/recipient pays recipient/sender
    int256 premium;
    // Links to specific set of transfer terms => this indicates which party is transferring their position
    bytes oracleSignature;
    bytes senderSignature;
    bytes recipientSignature;
    // Not used if the strategy is transferable
    bytes staticPartySignature;
}

// COMBINATION

struct CombinationTerms {
    uint256 strategyOneAlphaFee;
    uint256 strategyOneOmegaFee;
    uint256 resultingAlphaCollateralRequirement;
    uint256 resultingOmegaCollateralRequirement;
    int256 resultingAmplitude;
    int[2][] resultingPhase;
    uint256 oracleNonce;
}

struct CombinationParameters {
    uint256 strategyOneId;
    uint256 strategyTwoId;
    bytes strategyOneAlphaSignature;
    bytes strategyOneOmegaSignature;
    bytes oracleSignature;
}

// EXERCISE

struct ExerciseTerms {
    // If payout is +ve => alpha pays omega, if payout is -ve => omega pays alpha
    int256 payout;
    uint256 oracleNonce;
}

struct ExerciseParameters {
    bytes oracleSignature;
    uint256 strategyId;
}

// LIQUIDATE

struct LiquidationTerms {
    uint256 oracleNonce;
    // Basis transferred from one party to other as compensation for any value loss they experience due to amplitude reduction
    int256 compensation;
    // The fee paid by alpha during liquidation
    uint256 alphaFee;
    // The fee paid by omega during liquidation
    uint256 omegaFee;
    // The value the liquidated strategy's amplitude is reduced to in order to maintain collateralisation
    int256 postLiquidationAmplitude;
}

struct LiquidationParameters {
    uint256 strategyId;
    bytes oracleSignature;
}
