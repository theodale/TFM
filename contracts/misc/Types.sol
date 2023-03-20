// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

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
}

struct SpearmintDataPackage {
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
    // Trufin orcale signature for the spearmint's data pacakge => links spearminter approval to strategy detailed by the package
    bytes trufinOracleSignature;
    address alpha;
    address omega;
    int256 premium;
    bool transferable;
}

// OLD

struct CollateralLock {
    uint256 amount;
    uint256 lockExpiry;
}

struct CollateralParamsFull {
    uint256 expiry;
    uint256 alphaCollateralRequirement;
    uint256 omegaCollateralRequirement;
    uint256 collateralNonce;
    address bra;
    address ket;
    address basis;
    int256 amplitude;
    uint256 maxNotional;
    int256[2][] phase;
}

struct CollateralParamsID {
    uint256 strategyID;
    uint256 alphaCollateralRequirement;
    uint256 omegaCollateralRequirement;
    uint256 collateralNonce;
}

struct ReallocateCollateralRequest {
    address sender;
    address alpha;
    address omega;
    uint256 alphaCollateralRequirement;
    uint256 omegaCollateralRequirement;
    uint256 fromStrategyID;
    uint256 toStrategyID;
    uint256 amount;
    address basis;
}

struct PeppermintRequest {
    address sender;
    uint256 strategyID;
    address alpha;
    address omega;
    uint256 alphaCollateralRequired;
    uint256 omegaCollateralRequired;
    address basis;
    int256 premium;
    uint256 particleMass;
}

struct CollateralMoveRequest {
    address sender1;
    address sender2;
    uint256 strategyID;
    uint256 particleMass;
    address alpha;
    address omega;
    int256 premium;
    uint256 alphaCollateralRequirement;
    uint256 omegaCollateralRequirement;
    address basis;
    bool isAlpha;
    bool isTransfer;
}

struct CombineRequest {
    address alpha;
    address omega;
    uint256 thisStrategyID;
    uint256 targetStrategyID;
    uint256 particleMass;
    address basis;
    bool strategiesCancelOut;
}

struct LiquidationParams {
    uint256 collateralNonce;
    // The amount of basis transferred from omega to alpha as compensation for any value loss they experience due to amplitude reduction
    uint256 alphaCompensation;
    // The amount of basis transferred from alpha to omega as compensation for any value loss they experience due to amplitude reduction
    uint256 omegaCompensation;
    // The fee paid by alpha during liquidation
    uint256 alphaFee;
    // The fee paid by omega during liquidation
    uint256 omegaFee;
    // The value the liquidated strategy's amplitude is reduced to in order to maintain collateralisation
    int256 newAmplitude;
    // The new max notional of the liquidated strategy
    uint256 newMaxNotional;
    // The amount of basis alpha has allocated to the strategy pre-liquidation
    uint256 initialAlphaAllocation;
    // The amount of basis omega has allocated to the strategy pre-liquidation
    uint256 initialOmegaAllocation;
}

struct LiquidateRequest {
    uint256 strategyID;
    address alpha;
    address omega;
    uint256 transferredCollateralAlpha;
    uint256 transferredCollateralOmega;
    uint256 confiscatedCollateralAlpha;
    uint256 confiscatedCollateralOmega;
    address basis;
    bool confiscateAlpha;
    bool confiscateOmega;
}

struct NovateParams {
    bytes sigWeb2;
    bytes sig1;
    bytes sig2;
    bytes sig3;
    uint256 thisStrategyID;
    uint256 targetStrategyID;
    uint256 collateralNonce;
}

struct CombineParams {
    bytes sigWeb2;
    bytes sig1;
    bytes sig2;
    uint256 thisStrategyID;
    uint256 targetStrategyID;
    uint256 collateralNonce;
}

struct TransferParams {
    bytes sigWeb2;
    bytes sig1;
    bytes sig2;
    bytes sig3;
    uint256 thisStrategyID;
    address targetUser;
    uint256 strategyNonce;
    int256 premium;
    bool alphaTransfer;
}

struct SpearmintParams {
    bytes sigWeb2;
    bytes sig1;
    bytes sig2;
    address alpha;
    address omega;
    int256 premium;
    bool transferable;
    uint256 pairNonce;
}

struct DecomposedWaveFunction {
    int256[2][] phase;
    int256 amplitude;
    uint256 maxNotional;
}
