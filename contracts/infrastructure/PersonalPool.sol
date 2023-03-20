// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.14;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPersonalPool} from "../interfaces/IPersonalPool.sol";
import "../interfaces/IWrappedNativeCoin.sol";
import "../interfaces/ICollateralManager.sol";

/**
    @title Personal pools store collateral allocations per user.
    @notice Personal pools are created per user interacting with the TFM, to ensure separation between 
    user funds to minimise contamination risks. Collateral allocations are stored for unallocated and allocated
    collateral per basis. Users are exepected to interact with their personal pools through the TFM / Collateral Manager.
    @dev Additional documentation can be found on notion @ https://www.notion.so/trufin/V2-Documentation-6a7a43f8b577411d84277fc543f99063?d=63b28d74feba48c6be7312709a31dbe9#5bff636f9d784712af5de7df0a19ea72
*/
// TODO: this contract could be made upgradeable
contract PersonalPool is IPersonalPool {
    using SafeERC20 for IERC20;

    /**
        @notice Address of the Collateral Manager contract.
    */
    address immutable collateralManagerAddress;

    constructor() {
        collateralManagerAddress = msg.sender;
    }

    /**
        @notice Modifier to check that msg.sender is the Collateral Manager.
    */
    modifier isCollateralManager() {
        require(msg.sender == collateralManagerAddress, "A3");
        _;
    }

    /**
        @notice Function to approve the transfer of funds for msg.sender (the Collateral Manager).
        @param _basisAddress address of ERC20 token to be approved
        @param _amount of ERC20 token to approve
    */
    function approve(
        address _basisAddress,
        uint256 _amount
    ) external isCollateralManager {
        IERC20(_basisAddress).safeApprove(msg.sender, _amount);
    }

    /**
        @notice Function to withdraw Native coin from PersonalPool
        @param _to address which will be used as a recipient
        @param _amount of native coin to withdraw
    */
    function transferNative(
        address payable _to,
        uint256 _amount
    ) external isCollateralManager {
        ICollateralManager(collateralManagerAddress)
            .getWrappedNativeCoin()
            .withdraw(_amount);
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "C45");
    }

    function transferERC20(
        address _basisAddress,
        address _to,
        uint256 _amount
    ) external isCollateralManager {
        IERC20(_basisAddress).safeTransfer(_to, _amount);
    }

    /**
        @notice allow PersonalPool to receive Native coin during withdrawal from wrapped Native coin 
     */
    receive() external payable {}
}
