// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

// Do we need this?
enum Action {
    MINT,
    TRANSFER,
    COMBINE,
    NOVATE
}

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
    // Indicates if the combination terms are for target strategies with same (true) or opposite (false) alpha and omegas
    bool aligned;
}

struct CombinationParameters {
    uint256 strategyOneId;
    uint256 strategyTwoId;
    bytes strategyOneAlphaSignature;
    bytes strategyOneOmegaSignature;
    bytes oracleSignature;
}

// struct LiquidationParams {
//     uint256 collateralNonce;
//     // The amount of basis transferred from omega to alpha as compensation for any value loss they experience due to amplitude reduction
//     uint256 alphaCompensation;
//     // The amount of basis transferred from alpha to omega as compensation for any value loss they experience due to amplitude reduction
//     uint256 omegaCompensation;
//     // The fee paid by alpha during liquidation
//     uint256 alphaFee;
//     // The fee paid by omega during liquidation
//     uint256 omegaFee;
//     // The value the liquidated strategy's amplitude is reduced to in order to maintain collateralisation
//     int256 newAmplitude;
//     // The new max notional of the liquidated strategy
//     uint256 newMaxNotional;
//     // The amount of basis alpha has allocated to the strategy pre-liquidation
//     uint256 initialAlphaAllocation;
//     // The amount of basis omega has allocated to the strategy pre-liquidation
//     uint256 initialOmegaAllocation;
// }
