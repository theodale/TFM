// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import "../misc/Types.sol";

interface ITFM {
    event Initialization();

    event Spearmint(uint256 strategyId);

    // /**
    //  * @notice event fires when TFM is initialised
    //  * @dev decided to use view fns instead of emitting params
    //  * where possible in order to save on code size
    //  */
    // event TFMInitialized();
    // /**
    //  * @notice event fires when new liquidator address is set
    //  * @param _liquidator new address to set for liquidator
    //  */
    // event SetLiquidatorAddress(address indexed _liquidator);
    // /**
    //  * @notice event fires when photon is set
    //  * @param _basis basis to change mass of
    //  * @param _mass mass of fee
    //  */
    // event SetPhoton(address indexed _basis, uint256 _mass);
    // /**
    //  * @notice event fires when particle is set
    //  * @param _action action to change mass of
    //  * @param _mass mass of fee
    //  */
    // event SetParticle(uint256 indexed _action, uint256 _mass);
    // /**
    //  * @notice event fires when allocated collateral reallocation happens from one strategy to another
    //  * @param _fromStrategyID from which strategy
    //  * @param _toStrategyID to which strategy
    //  * @param _amount amount that was reallocated
    //  */
    // event ReallocatedCollateral(
    //     uint256 indexed _fromStrategyID,
    //     uint256 indexed _toStrategyID,
    //     uint256 _amount
    // );
    // /**
    //  * @notice event fires when spearmint happens
    //  * @param _strategyID what id strategy received
    //  */
    // event Spearminted(uint256 indexed _strategyID);
    // /**
    //  * @notice event fires when pepermint happens
    //  * @param _strategyID what id strategy received
    //  */
    // event Pepperminted(uint256 indexed _strategyID);
    // /**
    //  * @notice event fires when transfer happens
    //  * @param _thisStrategyID strategy to tranfer from
    //  * @param _initiator transfer to this user
    //  */
    // event Transferred(
    //     uint256 indexed _thisStrategyID,
    //     address indexed _initiator
    // );
    // /**
    //  * @notice event fires when combine happens
    //  * @param _thisStrategyID what strategies to combine
    //  * @param _targetStrategyID what strategies to combine
    //  */
    // event Combined(
    //     uint256 indexed _thisStrategyID,
    //     uint256 indexed _targetStrategyID
    // );
    // /**
    //  * @notice event fires when novate happens
    //  * @param _thisStrategyID what strategies to novate
    //  * @param _targetStrategyID what strategies to novate
    //  */
    // event Novated(
    //     uint256 indexed _thisStrategyID,
    //     uint256 indexed _targetStrategyID
    // );
    // /**
    //  * @notice event fires when exercise happens
    //  * @param _strategyID what strategy is exercised
    //  * @param _caller address of the user who exercised his side
    //  */
    // event Exercised(uint256 indexed _strategyID, address _caller);
    // /**
    //  * @notice event fires when liquidate happens
    //  * @param _strategyID what strategy is taking part in liquidation
    //  */
    // event Liquidated(uint256 indexed _strategyID);
    // /**
    //  * @notice event fires when annihilate happens
    //  * @param _strategyID what strategy is annihilated
    //  */
    // event Annihilated(uint256 indexed _strategyID);
    // /**
    //  * @notice event fires when a strategy is deleted
    //  * @param _strategyID what strategy is deleted
    //  */
    // event Deleted(uint256 indexed _strategyID);
    // function spearmint(
    //     CollateralParamsFull calldata _collateralParams,
    //     SpearmintParams calldata _aParams
    // ) external;
    // /**
    //     @notice Function to mint a strategy for two parties by a third-party taking neither side of the strategy.
    //     This function ensures that _alpha and _omega are sufficiently collateralised to take up their side and
    //     that they have locked enough collateral to also cover any premium to be paid.
    //     In order to call this function, collateral requirements (from the Web2 backend) need to be sent.
    //     @dev This function is used by the auction house once an auction has completed, so that the
    //     filled orders can be minted. At this stage, both parties involved in the strategy to be minted
    //     must have locked enough collateral (with the auction house as the trusted locker), to cover
    //     collateral requirements and any premium to be paid. The collateral requirements must be provided
    //     by the auction initiator at the start of the auction.
    //     @param _params the parameters of the strategy to be minted (basis, expiry, amplitude, phase),
    //     the collateral requirements and the collateral nonce (the version of the web2 database used to compute reqs)
    //     @param _transferable flag to indicate if strategy is transferable w/o requiring approval
    //     @param _alpha address to take alpha side of strategy
    //     @param _omega adddress to take omega side of strategy
    //     @param _signature signature of _hashedMessage by AdminAddress
    //     @param _premium amount of premium
    //     note if +ve premium is paid by _omega to _alpha, and vice-versa if premium is -ve
    // */
    // function peppermint(
    //     CollateralParamsFull calldata _params,
    //     bool _transferable,
    //     address _alpha,
    //     address _omega,
    //     bytes calldata _signature,
    //     int256 _premium
    // ) external;
    // /************************************************
    //  *  Actions
    //  ***********************************************/
    // // function deleteAction(uint256 _strategyID) external;
    // /**
    //     @notice Function to annihilate an existing strategy, if msg.caller is either
    //     on both sides of a strategy, or if they are on one side and the other side has not been claimed.
    //     Note this function also deallocates any collateral allocated to the strategy by msg.caller.
    //     @param _strategyID the ID of the strategy to annihilate
    // */
    // function annihilate(uint256 _strategyID) external;
    // /**
    //     @notice Function for the recepient (_targetUser) of an approved transfer to finalise the transfer and gain ownership
    //     of the specified side. This function ensures that the recepient is sufficiently collateralised and has posted any required premium.
    //     @dev This function optionally transfer premium from the transfer initiator to the recepient or vice-versa if it has been specified,
    //     and deallocates any allocated collateral of the transfer initiator if successfull.
    //     @param _collateralParams struct containing the full parameters
    //     @param _params struct containing the parametere like the 3-4 party signatures and target user, premium
    // */
    // function transfer(
    //     CollateralParamsFull calldata _collateralParams,
    //     TransferParams calldata _params
    // ) external;
    // /**
    //     @notice Function to perform a combination of two stratgies shared between two users.
    //     @dev This action can only be performed on two stratgies where the two users are either
    //     alpha/omega on both strategies, or they are both alpha on one and omega on the other.
    //     This combination can be performed in one single step and called by anyone, as long as the signatures are correct.
    //     Note that we do not check collateral requirements here as the strategies are already shared
    //     between the same two users.
    //     @param _params is the input struct for the function, containing:
    //         1. thisStrategyID the ID of one of the two strategies to combine (this strategy
    //         will be updated to represent the combination of the two)
    //         2. targetStrategyID the ID of the other strategy to combine with (this strategy
    //         will be deleted)
    // */
    // function combine(CombineParams calldata _params) external;
    // /**
    //     @notice Function to initiate a novation of two stratgies shared between three users,
    //     in order to decrease the overall collateral locked in the system.
    //     @dev For a novation to be possible both strategies need to have the same phase
    //     (i.e.: the same strikes) but can have different amplitudes.
    //     Novations can either be complete -if the amplitudes are the same - or partial -if the amplitudes are not the same.
    //     function novate(NovateParams calldata _params) external;
    //     @param _params struct containing the parameters (thisStrategyID, targetStrategyID, actionCount1, actionCount2, timestamp)
    // */
    // function novate(NovateParams calldata _params) external;
    // /************************************************
    //  *  Option Functionality
    //  ***********************************************/
    // /**
    //     @notice Function to exercise an expired option.
    //     @dev Once a strategy has expired the Web2 backend will return alpha and omega payout
    //     instead of collateral requirements, however, the struct is reused to avoid redundancy.
    //     To ensure that the sent collateral information is correct (containing payouts instead of collateral requirements),
    //     we require that the collateral nonce in the data corresponds to the most recent version
    //     (instead of allowing collateral information from the previous checkpoint as with regular collateral information).
    //     Note that any gains are paid out as soon as the first party calls exercise, however, the strategy is only
    //     deleted once both parties have exercised for better UX.
    //     @param _paramsID struct containing the parameters (strategyID, collateral requirements, collateralNonce)
    //     @param _signature web2 signature of hashed message
    // */
    // function exercise(
    //     CollateralParamsID calldata _paramsID,
    //     bytes calldata _signature
    // ) external;
    // // /**
    // //     @dev Trusted liquidate function, where all data is assumed to be correct as it can be only sent by
    // //     the AdminAddress. Can specify any collateral that should be transferred and confiscated.
    // //     Note it is assumed that one of (_transferredCollateralAlpha, _transferredCollateralOmega) should be zero
    // //     otherwise _transferredCollateralAlpha takes priority.
    // //     @param _collateralParams the collateralRequirements from web2
    // //     @param _lParams input data (see definition of LiquidateParams)
    // // */
    // // function liquidate(
    // //     CollateralParamsID calldata _collateralParams,
    // //     LiquidateParams calldata _lParams
    // // ) external;
}
