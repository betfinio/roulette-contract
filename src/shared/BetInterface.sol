// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface BetInterface {
    /**
     * @return player - address of player
     */
    function getPlayer() external view returns (address);

    /**
     * @return amount - amount of bet
     */
    function getAmount() external view returns (uint256);

    /**
     * @return result - amount of payout
     */
    function getResult() external view returns (uint256);

    /**
     * @return status - status of bet
     */
    function getStatus() external view returns (uint256);

    /**
     * @return game - address of game
     */
    function getGame() external view returns (address);

    /**
     * @return timestamp - created timestamp of bet
     */
    function getCreated() external view returns (uint256);

    /**
     * @return data - all data at once (player, game, amount, result, status, created)
     */
    function getBetInfo() external view returns (address, address, uint256, uint256, uint256, uint256);
}
