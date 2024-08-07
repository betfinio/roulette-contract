// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface GameInterface {
    function getAddress() external view returns (address gameAddress);

    // for most games - creation timestamp of the game
    function getVersion() external view returns (uint256 version);

    // 0 - fee from player's bet, 1 - fee from core's balance
    function getFeeType() external pure returns (uint256 feeType);

    // address to send fee to
    function getStaking() external view returns (address staking);

    // function to call when placing bet
    function placeBet(address player, uint256 amount, bytes calldata data) external returns (address betAddress);
}
