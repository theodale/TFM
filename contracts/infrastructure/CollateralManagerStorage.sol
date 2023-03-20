// // SPDX-License-Identifier: GPL-3.0

// pragma solidity =0.8.14;

// import {CollateralLock} from "../misc/Types.sol";
// import "../interfaces/IWrappedNativeCoin.sol";

// abstract contract CollateralManagerStorage {
//     /**
//         @notice Mapping from user to Personal Pool, where collateral is stored.
//     */
//     mapping(address => address payable) public personalPools;
//     /**
//         @notice User to strategyID to allocated collateral mapping. Storing the
//         amount of allocated collateral a user has per strategy.
//         @dev allocatedCollateral[user][strategyID]
//     */
//     mapping(address => mapping(uint256 => uint256)) public allocatedCollateral;
//     /**
//         @notice User to basis to unallocated collateral mapping. Storing the amount
//         of unallocated collateral a user has per basis.
//         @dev unallocatedCollateral[user][basis]
//     */
//     mapping(address => mapping(address => uint256))
//         public unallocatedCollateral;

//     /**
//         @notice User to trusted locker to basis to locked collateral mapping. Storing
//         the amount of collateral a user has locked for a sepcific "trusted locker" 
//         per basis.
//         @dev lockedCollateral[user][pepperminter][basis] = (amount, lockExpiry)
//     */
//     mapping(address => mapping(address => mapping(address => CollateralLock)))
//         public lockedCollateral;
//     /**
//         @notice User to trusted locker to true/false. Mapping indicating what addresses 
//         have been set as trusted lockers for a given user.
//     */
//     mapping(address => mapping(address => bool)) public trustedLockers;

//     /**
//         @dev The treasury address, to which liquidation fees are sent.
//     */
//     address public TFMAddress;



//     address public Web2Address;
   
    

//     /**
//         @notice The nonce representing the most up-to-date version of the web2 database used to for collateral info.
//     */
//     uint256 public collateralNonce;

//     /**
//         @notice The wrapped native coin address which is used when user posts/withdraws native coin (to wrap/unwrap 
//         funds for unification use like other tokens)  
//     */
//     IWrappedNativeCoin internal wrappedNativeCoin;

//     /**
//         @notice Stores the timestamp of when the collateralNonce was last updated
//     */
//     uint256 internal latestCollateralNonceTime;


//     /**
//      * @dev This empty reserved space is put in place to allow future versions to add new
//      * variables without shifting down storage in the inheritance chain.
//      * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
//      */
//     uint256[49] private __gap;
// }
