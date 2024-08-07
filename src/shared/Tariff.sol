// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

contract Tariff {
    uint256 public immutable price; // amount of BET tokens to pay
    uint256 public immutable profit; // percentage of each bet, that partner will get (0_00 - 3_60)
    uint256 public immutable stakeProfit; // percentage of each stake, that partner will get (0_00 - 100_00)

    constructor(uint256 _price, uint256 _profit, uint256 _stakeProfit) {
        price = _price;
        profit = _profit;
        stakeProfit = _stakeProfit;
    }
}
