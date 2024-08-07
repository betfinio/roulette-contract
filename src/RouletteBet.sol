// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin/access/Ownable.sol";
import "./shared/BetInterface.sol";

contract RouletteBet is Ownable, BetInterface {
    struct Bet {
        uint256 amount;
        uint256 bitmap;
    }

    address private player;
    address private game;
    uint256 private totalAmount;
    uint256 private immutable created;
    // 1 - spinning
    // 2 - landed
    uint256 private status;
    uint256 private requestId;
    uint256 private result;
    uint256 private winNumber = 42;

    Bet[] private bets;

    constructor() {
        created = block.timestamp;
    }

    function getPlayer() external view override returns (address) {
        return player;
    }

    function getGame() external view override returns (address) {
        return game;
    }

    function getAmount() external view override returns (uint256) {
        return totalAmount;
    }

    function getStatus() external view override returns (uint256) {
        return status;
    }

    function getCreated() external view override returns (uint256) {
        return created;
    }

    function getResult() external view returns (uint256) {
        return result;
    }

    function getBetInfo()
        external
        view
        override
        returns (address, address, uint256, uint256, uint256, uint256)
    {
        return (player, game, totalAmount, result, status, created);
    }

    function getRequestId() external view returns (uint256) {
        return requestId;
    }

    function setPlayer(address _player) public onlyOwner {
        player = _player;
    }

    function setGame(address _game) public onlyOwner {
        game = _game;
    }

    function setAmount(uint256 _amount) public onlyOwner {
        totalAmount = _amount;
    }

    function setStatus(uint256 _status) public onlyOwner {
        status = _status;
    }

    function setRequestId(uint256 _requestId) public onlyOwner {
        requestId = _requestId;
    }

    function setResult(uint256 _result) public onlyOwner {
        result = _result;
    }

    function getWinNumber() public view returns (uint256) {
        return winNumber;
    }

    function setWinNumber(uint256 _winNumber) public onlyOwner {
        winNumber = _winNumber;
    }

    function getBetsCount() public view returns (uint256) {
        return bets.length;
    }

    function getBet(uint256 index) public view returns (uint256, uint256) {
        return (bets[index].amount, bets[index].bitmap);
    }

    function setBets(uint256 count, uint256[] calldata _bets) public onlyOwner {
        require(count * 2 == _bets.length, "roulette.wrong-data-length");
        for (uint256 i = 0; i < count; i++) {
            Bet memory bet;
            bet.amount = _bets[i * 2];
            bet.bitmap = _bets[i * 2 + 1];
            bets.push(bet);
        }
    }

    function getBets()
        public
        view
        returns (uint256[] memory, uint256[] memory)
    {
        uint count = bets.length;
        uint256[] memory amounts = new uint256[](count);
        uint256[] memory bitmaps = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            amounts[i] = bets[i].amount;
            bitmaps[i] = bets[i].bitmap;
        }
        return (amounts, bitmaps);
    }
}
