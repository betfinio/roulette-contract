// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/access/AccessControl.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "./staking/StakingInterface.sol";
import "./games/GameInterface.sol";
import "./BetsMemory.sol";
import "./Partner.sol";
import "./Tariff.sol";
import "./Pass.sol";

/**
 * Error codes used in this contract:
 * C01 - error when trying to create tariff with profit more than fee itself
 * C02 - tariff not found
 * C02 - invalid version of deployed Game contract
 * C04 - game not found
 * C05 - invalid staking address
 * C06 - staking not found
 * C07 - invalid Pass membership
 * C08 - insufficient allowance
 * C09 - invalid price when creating new tariff
 * C10 - invalid stake pro  fit when creating new tariff
 * C11 - invalid amount to bet
 * C12 - invalid amount to stake
 */
contract Core is AccessControl {
    using SafeERC20 for ERC20;

    uint256 public constant fee = 3_60;
    bytes32 public constant PARTNER = keccak256("PARTNER");
    bytes32 public constant TIMELOCK = keccak256("TIMELOCK");

    ERC20 public token;
    Pass public pass;
    BetsMemory public betsMemory;

    event TariffCreated(address indexed tariff);
    event TariffRemoved(address indexed tariff);
    event GameCreated(address indexed game);
    event GameRemoved(address indexed game);
    event StakingCreated(address indexed staking);
    event StakingRemoved(address indexed staking);
    event PartnerCreated(address indexed partner);

    address[] private games;
    address[] private stakings;
    address[] private partners;
    address[] private tariffs;
    mapping(address => uint256) private gameIndex;
    mapping(address => uint256) private stakingIndex;
    mapping(address => uint256) private tariffIndex;

    constructor(
        address _token,
        address _betsMemory,
        address _pass,
        address _admin
    ) {
        token = ERC20(_token);
        betsMemory = BetsMemory(_betsMemory);
        pass = Pass(_pass);
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /* ================================================TARIFF START================================================= */

    function addTariff(
        uint256 _price,
        uint256 _profit,
        uint256 _stakeProfit
    ) external onlyRole(TIMELOCK) returns (address) {
        require(_profit <= fee, "C01");
        require(_stakeProfit <= 100_00, "C10");
        Tariff tariff = new Tariff(_price, _profit, _stakeProfit);
        tariffs.push(address(tariff));
        tariffIndex[address(tariff)] = tariffs.length;
        emit TariffCreated(address(tariff));
        return address(tariff);
    }

    function removeTariff(address tariffAddress) external onlyRole(TIMELOCK) {
        require(tariffIndex[tariffAddress] > 0, "C02");
        tariffs[tariffIndex[tariffAddress] - 1] = tariffs[tariffs.length - 1];
        tariffIndex[tariffs[tariffs.length - 1]] = tariffIndex[tariffAddress];
        tariffs.pop();
        tariffIndex[tariffAddress] = 0;
        emit TariffRemoved(tariffAddress);
    }

    function getTariffs() public view returns (address[] memory) {
        return tariffs;
    }

    /* =================================================TARIFF END================================================== */

    /* ===============================================PARTNER START================================================= */

    function addPartner(address _tariff) external returns (address) {
        // check if tariff exists
        require(tariffIndex[_tariff] > 0, "C02");
        // get tariff
        Tariff tariff = Tariff(_tariff);
        // transfer payment
        token.transferFrom(_msgSender(), address(this), tariff.price());
        // create partner
        Partner partner = new Partner(_tariff, _msgSender());
        // add partner to array
        partners.push(address(partner));
        // grant PARTNER role
        _grantRole(PARTNER, address(partner));
        // emit event
        emit PartnerCreated(address(partner));
        // return partner address
        return address(partner);
    }

    function getPartners() public view returns (address[] memory) {
        return partners;
    }

    /* ================================================PARTNER END================================================== */

    /* ================================================GAME START=================================================== */

    function addGame(address game) external onlyRole(TIMELOCK) {
        require(GameInterface(game).getVersion() > 0, "C03");
        games.push(game);
        gameIndex[game] = games.length;
        emit GameCreated(game);
    }

    function getGames() external view returns (address[] memory) {
        return games;
    }

    function isGame(address _game) external view returns (bool) {
        return gameIndex[_game] > 0;
    }

    function isStaking(address _staking) external view returns (bool) {
        return stakingIndex[_staking] > 0;
    }

    function removeGame(address game) external onlyRole(TIMELOCK) {
        require(gameIndex[game] > 0, "C04");
        games[gameIndex[game] - 1] = games[games.length - 1];
        gameIndex[games[games.length - 1]] = gameIndex[game];
        games.pop();
        gameIndex[game] = 0;
        emit GameRemoved(game);
    }

    /* ================================================GAME END================================================== */

    /* ================================================STAKING START=================================================== */

    function addStaking(address staking) external onlyRole(TIMELOCK) {
        require(StakingInterface(staking).getAddress() != address(0), "C05");
        stakings.push(staking);
        stakingIndex[staking] = stakings.length;
        emit StakingCreated(staking);
    }

    function getStakings() external view returns (address[] memory) {
        return stakings;
    }

    function removeStaking(address staking) external onlyRole(TIMELOCK) {
        require(
            stakingIndex[staking] > 0 &&
                stakingIndex[staking] <= stakings.length,
            "C06"
        );
        require(stakings.length > 0, "Stakings array is empty");
        uint256 stakingIndexToRemove = stakingIndex[staking] - 1;
        address lastStaking = stakings[stakings.length - 1];
        // Swap the staking to be removed with the last staking in the array
        stakings[stakingIndexToRemove] = lastStaking;
        // Update the index of the last staking to reflect its new position
        stakingIndex[lastStaking] = stakingIndexToRemove + 1;
        // Remove the last element from the array
        stakings.pop();
        // Clear the index for the removed staking
        stakingIndex[staking] = 0;
        emit StakingRemoved(staking);
    }

    /* ================================================STAKING END================================================== */

    function placeBet(
        address player,
        address game,
        uint256 totalAmount,
        bytes memory data
    ) external onlyRole(PARTNER) returns (address bet) {
        // check if player has pass
        require(pass.balanceOf(player) > 0, "C07");
        // check if game is registered
        require(gameIndex[game] > 0, "C04");
        // check if totalAmount > 1
        require(totalAmount >= 1, "C11");
        // fetch the game
        GameInterface iGame = GameInterface(games[gameIndex[game] - 1]);
        // calculate base fee
        uint256 baseFee = ((totalAmount * fee) / 100_00);
        // calculate partner fee
        uint256 partnerFee = (totalAmount *
            Tariff(Partner(_msgSender()).tariff()).profit()) / 100_00;
        if (iGame.getFeeType() == 0) {
            // send fee to partner
            token.transferFrom(player, _msgSender(), partnerFee);
            // send fee to staking
            token.transferFrom(
                player,
                iGame.getStaking(),
                baseFee - partnerFee
            );
            // send bet amount - fee to game
            token.transferFrom(player, game, totalAmount - baseFee);
        } else if (iGame.getFeeType() == 1) {
            // send fee to partner
            token.transfer(_msgSender(), partnerFee);
            // send whole bet amount to game
            token.transferFrom(player, game, totalAmount);
        }
        // create bet
        bet = iGame.placeBet(player, totalAmount, data);
        // add bet to memory
        betsMemory.addBet(bet);
        // return bet address
        return bet;
    }

    function stake(
        address player,
        address staking,
        uint256 amount
    ) external onlyRole(PARTNER) {
        // check if player has pass
        require(pass.balanceOf(player) > 0, "C07");
        // check if staking is registered
        require(stakingIndex[staking] > 0, "C06");
        // check if amount > 1
        require(amount >= 1, "C12");
        // check allowance
        require(token.allowance(player, address(this)) >= amount, "C08");
        // transfer tokens
        token.transferFrom(player, address(this), amount);
        // approve token spending
        token.approve(staking, amount);
        // stake
        StakingInterface(staking).stake(player, amount);
        // send profit to partner
        token.transfer(
            _msgSender(),
            (amount * Tariff(Partner(_msgSender()).tariff()).stakeProfit()) /
                100_00
        );
    }
}
