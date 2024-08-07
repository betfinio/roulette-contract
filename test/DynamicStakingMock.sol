// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../src/shared/staking/StakingInterface.sol";
import "openzeppelin/access/AccessControl.sol";
import "../src/shared/Token.sol";

contract DynamicStakingMock is StakingInterface, AccessControl {
    bytes32 public constant TIMELOCK = keccak256("TIMELOCK");
    bytes32 public constant GAME = keccak256("GAME");

    Token immutable token;

    constructor(address _token) {
        token = Token(_token);
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function totalStaked() external pure override returns (uint256) {
        return 0;
    }

    function totalStakers() external pure override returns (uint256) {
        return 0;
    }

    function getToken() external view override returns (address) {
        return address(token);
    }

    function getAddress() external view override returns (address) {
        return address(this);
    }

    function getStaked(address) external pure override returns (uint256) {
        return 0;
    }

    function reserveFunds(uint256 amount) external override onlyRole(GAME) {
        token.transfer(_msgSender(), amount);
    }

    function addGame(address _game) external onlyRole(TIMELOCK) {
        _grantRole(GAME, _game);
    }
    function stake(address staker, uint256 amount) external override {}
}
