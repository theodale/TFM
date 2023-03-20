// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IPersonalPool.sol";
import "../interfaces/ICollateralManager.sol";

// Used Minimal clones?
contract PersonalPool is IPersonalPool {
    using SafeERC20 for IERC20;

    address immutable collateralManagerAddress;

    constructor() {
        collateralManagerAddress = msg.sender;
    }

    modifier isCollateralManager() {
        require(
            msg.sender == collateralManagerAddress,
            "PersonalPool: Collateral Manager only"
        );
        _;
    }

    function transferERC20(
        address _basisAddress,
        address _to,
        uint256 _amount
    ) external isCollateralManager {
        IERC20(_basisAddress).safeTransfer(_to, _amount);
    }

    // Allows contract to receive native coin
    receive() external payable {}
}
