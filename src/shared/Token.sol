// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "openzeppelin/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    uint256 public constant initialSupply = 777_777_777_777 ether;

    constructor(address receiver) ERC20("BET", "BET") {
        _mint(receiver, initialSupply);
    }
}
