// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../interfaces/IWallet.sol";
import "../interfaces/ICollateralManager.sol";

contract Wallet is IWallet, Initializable {
    using SafeERC20 for IERC20;

    address collateralManager;

    function initialize() external initializer {
        collateralManager = msg.sender;
    }

    modifier isCollateralManager() {
        require(msg.sender == collateralManager, "PersonalPool: Collateral Manager only");
        _;
    }

    function transferERC20(address _basis, address _recipient, uint256 _amount) external isCollateralManager {
        IERC20(_basis).safeTransfer(_recipient, _amount);
    }
}