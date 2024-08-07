// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "openzeppelin/access/Ownable.sol";
import "./Tariff.sol";
import "./Core.sol";

/**
 * Errors used in this contract:
 * PA01 - bet amount is zero
 * PA02 - staked amount is zero
 */
contract Partner is Ownable {
    Tariff public tariff;
    Core private core;

    constructor(address _tariff, address owner) {
        core = Core(_msgSender());
        tariff = Tariff(_tariff);
        _transferOwnership(owner);
    }

    function placeBet(
        address game,
        uint256 totalAmount,
        bytes calldata data
    ) public returns (address) {
        require(totalAmount > 0, "PA01");
        return core.placeBet(_msgSender(), game, totalAmount, data);
    }

    function stake(address staking, uint256 amount) public {
        require(amount > 0, "PA02");
        core.stake(_msgSender(), staking, amount);
    }

    function withdraw() public onlyOwner {
        core.token().transfer(owner(), core.token().balanceOf(address(this)));
    }
}
