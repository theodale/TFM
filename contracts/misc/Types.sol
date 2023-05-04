// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

// *** PROTOCOL STATE REPRESENTATIONS ***

struct Strategy {
    bool transferable;
    address bra;
    address ket;
    address basis;
    // These can be inferred from allocations
    address alpha;
    address omega;
    uint48 expiry;
    int256 amplitude;
    int256[2][] phase;
    // Prevents replay of certain strategy action meta-transactions
    uint256 actionNonce;
}

struct Allocation {
    uint256 alphaBalance;
    uint256 omegaBalance;
}

// Represents escrowed deposits used for peppermints
struct LockedDeposit {
    uint256 amount;
    uint256 unlockTime;
}

// *** TFM ACTION PARAMETERS ***

struct SpearmintParameters {
    uint48 expiry;
    address bra;
    address ket;
    address basis;
    int256 amplitude;
    int256[2][] phase;
    bytes oracleSignature;
    uint256 oracleNonce;
    uint256 alphaCollateralRequirement;
    uint256 omegaCollateralRequirement;
    uint256 alphaFee;
    uint256 omegaFee;
    address alpha;
    address omega;
    int256 premium;
    bool transferable;
    bytes alphaSignature;
    bytes omegaSignature;
}

struct PeppermintParameters {
    uint48 expiry;
    address bra;
    address ket;
    address basis;
    int256 amplitude;
    int256[2][] phase;
    bytes oracleSignature;
    uint256 oracleNonce;
    uint256 alphaCollateralRequirement;
    uint256 omegaCollateralRequirement;
    uint256 alphaFee;
    uint256 omegaFee;
    address alpha;
    address omega;
    int256 premium;
    bool transferable;
    uint256 alphaDepositId;
    uint256 omegaDepositId;
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
    uint256 recipientCollateralRequirement;
    uint256 oracleNonce;
    uint256 senderFee;
    uint256 recipientFee;
    bool alphaTransfer;
}

struct CombinationParameters {
    uint256 strategyOneAlphaFee;
    uint256 strategyOneOmegaFee;
    uint256 resultingAlphaCollateralRequirement;
    uint256 resultingOmegaCollateralRequirement;
    int256 resultingAmplitude;
    int256[2][] resultingPhase;
    uint256 oracleNonce;
    // True if alpha and omega hold same positions in both strategies
    bool aligned;
    uint256 strategyOneId;
    uint256 strategyTwoId;
    bytes alphaOneSignature;
    bytes omegaOneSignature;
    bytes oracleSignature;
}

struct NovationParameters {
    uint256 strategyOneId;
    uint256 strategyTwoId;
    bytes oracleSignature;
    bytes middlePartySignature;
    // These signatures below are not used if their respective strategy is transferable
    bytes strategyOneNonMiddlePartySignature;
    bytes strategyTwoNonMiddlePartySignature;
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

struct ExerciseParameters {
    // If payout is +ve/-ve => alpha/omega pays omega/alpha
    int256 payout;
    uint256 oracleNonce;
    bytes oracleSignature;
    uint256 strategyId;
}

struct LiquidationParameters {
    uint256 oracleNonce;
    // If +ve/-ve => alpha/omega pays omega/alpha absolute compensation
    int256 compensation;
    // The collateral taken from allocations by the protocol
    uint256 alphaPenalisation;
    uint256 omegaPenalisation;
    int256 postLiquidationAmplitude;
    uint256 strategyId;
    bytes oracleSignature;
}

// *** PROTOCOL-INTERNAL PARAMETERS ***

struct ExecutePeppermintParameters {
    uint256 strategyId;
    address alpha;
    address omega;
    address basis;
    int256 premium;
    uint256 alphaCollateralRequirement;
    uint256 omegaCollateralRequirement;
    uint256 alphaFee;
    uint256 omegaFee;
    address pepperminter;
    uint256 alphaDepositId;
    uint256 omegaDepositId;
}

struct ExecuteTransferParameters {
    uint256 strategyId;
    address sender;
    address recipient;
    address basis;
    uint256 recipientCollateralRequirement;
    uint256 senderFee;
    uint256 recipientFee;
    int256 premium;
    bool alphaTransfer;
}

struct ExecuteCombinationParameters {
    uint256 strategyOneId;
    uint256 strategyTwoId;
    uint256 resultingAlphaCollateralRequirement;
    uint256 resultingOmegaCollateralRequirement;
    address basis;
    address alphaOne;
    address omegaOne;
    uint256 alphaOneFee;
    uint256 omegaOneFee;
    bool aligned;
}

struct ApprovePeppermintParameters {
    uint48 expiry;
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
    address oracle;
    bytes oracleSignature;
}

struct ApproveLiquidationParameters {
    uint256 oracleNonce;
    int256 compensation;
    uint256 alphaPenalisation;
    uint256 omegaPenalisation;
    int256 postLiquidationAmplitude;
    uint256 alphaInitialCollateral;
    uint256 omegaInitialCollateral;
    address oracle;
    bytes oracleSignature;
}

struct SharedMintLogicParameters {
    uint256 strategyId;
    address alpha;
    address omega;
    address basis;
    int256 premium;
    uint256 alphaCollateralRequirement;
    uint256 omegaCollateralRequirement;
    uint256 alphaAvailable;
    uint256 omegaAvailable;
    uint256 alphaFee;
    uint256 omegaFee;
}
