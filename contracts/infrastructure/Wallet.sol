// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../interfaces/IWallet.sol";

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

    // We have this to avoid multiple calls from CollateralManager to wallet during calls
    function transferERC20Twice(
        address _basis,
        address _recipientOne,
        uint256 _amountOne,
        address _recipientTwo,
        uint256 _amountTwo
    ) external isCollateralManager {
        IERC20(_basis).safeTransfer(_recipientOne, _amountOne);
        IERC20(_basis).safeTransfer(_recipientTwo, _amountTwo);
    }
}
