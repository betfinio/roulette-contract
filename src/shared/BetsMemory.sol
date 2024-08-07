// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "openzeppelin/access/AccessControl.sol";
import "./BetInterface.sol";
import "./games/GameInterface.sol";
import "./Pass.sol";

contract BetsMemory is AccessControl {
    bytes32 public constant AGGREGATOR = keccak256("AGGREGATOR");
    bytes32 public constant TIMELOCK = keccak256("TIMELOCK");

    mapping(address => uint256) public playersVolume;
    mapping(address => uint256) public gamesVolume;
    mapping(address => uint256) public totalVolumeOfInvitees;
    mapping(address => uint256) public betsCountByStaking;
    mapping(address => BetInterface[]) public playersBets;
    mapping(address => BetInterface[]) public gamesBets;

    Pass public pass;
    BetInterface[] public bets;

    event NewBet(
        address indexed bet,
        address indexed player,
        address indexed game
    );
    event NewAggregator(address indexed aggregator);
    event AggregatorRemoved(address indexed aggregator);
    event NewPass(address indexed pass);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function getBets() public view returns (BetInterface[] memory) {
        return bets;
    }

    function getBet(uint256 _index) public view returns (BetInterface) {
        return bets[_index];
    }

    function getBets(
        uint256 limit,
        uint256 offset,
        address _game
    ) public view returns (BetInterface[] memory) {
        uint256 _limit = limit;
        uint256 _offset = offset;

        if (_limit > bets.length) {
            _limit = bets.length;
        }
        if (_limit > 128) {
            _limit = 128;
        }
        BetInterface[] memory result = new BetInterface[](_limit);
        if (_limit == 0 || bets.length == 0) {
            return result;
        }
        uint256 resultIndex = 0;
        for (uint256 i = bets.length - 1 - _offset; i >= 0; i--) {
            if (
                _game == address(0) || BetInterface(bets[i]).getGame() == _game
            ) {
                result[resultIndex] = bets[i];
                resultIndex++;
                if (resultIndex == _limit) {
                    break;
                }
            }
        }
        return result;
    }

    function getLastBets(
        uint256 count
    ) public view returns (BetInterface[] memory) {
        uint256 _count = count;
        if (bets.length == 0 || _count == 0) return new BetInterface[](0);
        if (_count > bets.length) {
            _count = bets.length;
        }
        if (_count > 100) {
            _count = 100;
        }
        BetInterface[] memory result = new BetInterface[](_count);
        uint256 index = 0;
        for (uint256 i = bets.length - 1; i >= 0; i--) {
            result[index] = bets[i];
            index++;
            if (index == _count) break;
        }
        return result;
    }

    function getPlayersVolume(address _player) public view returns (uint256) {
        return playersVolume[_player];
    }

    function getPlayerBetsCount(address _player) public view returns (uint256) {
        return playersBets[_player].length;
    }

    function getBetsCount() public view returns (uint256) {
        return bets.length;
    }

    function getGamesBetsCount(address _game) public view returns (uint256) {
        return gamesBets[_game].length;
    }

    function addBet(address _bet) public onlyRole(AGGREGATOR) {
        BetInterface bet = BetInterface(_bet);
        address player = bet.getPlayer();
        address game = bet.getGame();
        address inviter = pass.getInviter(player);
        bets.push(bet);
        playersVolume[player] += bet.getAmount();
        playersBets[player].push(bet);
        gamesVolume[game] += bet.getAmount();
        gamesBets[game].push(bet);
        totalVolumeOfInvitees[inviter] += bet.getAmount();
        betsCountByStaking[GameInterface(game).getStaking()]++;
        emit NewBet(_bet, player, game);
    }

    function addAggregator(address _aggregator) public onlyRole(TIMELOCK) {
        _grantRole(AGGREGATOR, _aggregator);
        emit NewAggregator(_aggregator);
    }

    function removeAggregator(address _aggregator) public onlyRole(TIMELOCK) {
        _revokeRole(AGGREGATOR, _aggregator);
        emit AggregatorRemoved(_aggregator);
    }

    function setPass(address _pass) public onlyRole(TIMELOCK) {
        pass = Pass(_pass);
        emit NewPass(_pass);
    }
}
