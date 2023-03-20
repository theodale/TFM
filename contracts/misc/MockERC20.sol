// SPDX-License-Identifier: MIT
pragma solidity =0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20("MockERC20", "MCK") {
    function mint(address _receiver, uint256 _amount) public {
        _mint(_receiver, _amount);
    }
}
