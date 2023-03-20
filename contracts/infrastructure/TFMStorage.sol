// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.14;

import {Strategy} from "../misc/Types.sol";
import {CollateralManager} from "./CollateralManager.sol";

abstract contract TFMStorage {
    /**
        @notice Stores collateral manager contract, used to post / withdraw / allocate / lock collateral
        and verify collateral requirements
    */
    ///@custom:security non-reentrant
    CollateralManager public collateralManager;

    /**
        @notice Map strategy ids to strategy structs.
    */
    mapping(uint256 => Strategy) internal strategies;

    /**
        @notice Map ERC20 addresses to price of $10.
    */
    mapping(address => uint256) public photons;

    /**
        @notice Tracks most recent strategy id minted.
    */
    uint256 public strategyCounter;

    /**
        @notice Defines Liquidator of the contract for liquidations.
    */
    address internal liquidator;

    /**
        @dev Maps Strategy IDs to the actions they have completed (nonce)
    */
    mapping(uint256 => uint256) public strategyNonce;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
