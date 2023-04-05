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
    // Prevents replay of certain strategy action meta-transactions
    uint256 actionNonce;
}

// *** ACTIONS ***

// MINT

struct MintTerms {
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

struct MintParameters {
    bytes oracleSignature;
    address alpha;
    address omega;
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

// COMBINE

struct CombinationTerms {
    uint256 strategyOneAlphaFee;
    uint256 strategyOneOmegaFee;
    uint256 resultingAlphaCollateralRequirement;
    uint256 resultingOmegaCollateralRequirement;
    int256 resultingAmplitude;
    int256[2][] resultingPhase;
    uint256 oracleNonce;
    // True if alpha and omega hold same positions in both strategies
    bool aligned;
}

struct CombinationParameters {
    uint256 strategyOneId;
    uint256 strategyTwoId;
    bytes strategyOneAlphaSignature;
    bytes strategyOneOmegaSignature;
    bytes oracleSignature;
}

// NOVATE

struct NovationTerms {
    uint256 oracleNonce;
    // Collateral requirements of resulting strategies
    uint256 strategyOneResultingAlphaCollateralRequirement;
    uint256 strategyOneResultingOmegaCollateralRequirement;
    uint256 strategyTwoResultingAlphaCollateralRequirement;
    uint256 strategyTwoResultingOmegaCollateralRequirement;
    // Characteristics of resulting strategies
    int256 strategyOneResultingAmplitude;
    int256 strategyTwoResultingAmplitude;
    // Action fee paid by middle party
    uint256 fee;
}

struct NovationParameters {
    uint256 strategyOneId;
    uint256 strategyTwoId;
    bytes oracleSignature;
    bytes middlePartySignature;
    // These are not used if their respective strategy is transferable
    bytes strategyOneNonMiddlePartySignature;
    bytes strategyTwoNonMiddlePartySignature;
    bool updateStrategyTwoOmega;
}

// EXERCISE

struct ExerciseTerms {
    // If payout is +ve/-ve => alpha/omega pays omega/alpha
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
    // If +ve/-ve => alpha/omega pays omega/alpha absolute compensation
    int256 compensation;
    // The collateral taken from allocations by the protocol
    uint256 alphaPenalisation;
    uint256 omegaPenalisation;
    int256 postLiquidationAmplitude;
}

struct LiquidationParameters {
    uint256 strategyId;
    bytes oracleSignature;
}
