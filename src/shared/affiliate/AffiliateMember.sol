// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "openzeppelin/access/AccessControl.sol";

/**
Errors used in this contract:

* AM01 - affiliate address is zero
*/

abstract contract AffiliateMember is AccessControl {
    bytes32 public constant AFFILIATE = keccak256("AFFILIATE");
    bytes32 public constant TIMELOCK = keccak256("TIMELOCK");

    address public affiliate;
    address public root;
    uint256 internal membersCount;

    event NewMember(address indexed member, address indexed inviter, address indexed parent);

    mapping(address => address) internal inviters;
    mapping(address => bool) internal isMember;
    mapping(address => uint256) internal inviteesCount;
    mapping(address => address[]) internal invitees;
    mapping(address => uint256) internal claimedDirectStakingBonus;
    mapping(address => uint256) internal claimedDirectBettingBonus;
    mapping(address => uint256) internal claimedMatchingBonus;

    function _push(address member, address inviter) internal {
        if (root == address(0)) root = member;
        isMember[member] = true;
        membersCount++;
        inviters[member] = inviter;
        inviteesCount[inviter]++;
        invitees[inviter].push(member);
    }

    function getInviter(address member) external view returns (address) {
        return inviters[member];
    }

    function getInviteesCount(address member) external view returns (uint256) {
        return inviteesCount[member];
    }

    function getMembersCount() public view returns (uint256) {
        return membersCount;
    }

    function getInvitee(address inviter, uint256 index) external view returns (address) {
        return invitees[inviter][index];
    }

    function getInvitees(address inviter) external view returns (address[] memory) {
        return invitees[inviter];
    }

    function claimDirectBettingBonus(address member, uint256 amount) external onlyRole(AFFILIATE) {
        _claimDirectBettingBonus(member, amount);
    }

    function claimDirectStakingBonus(address member, uint256 amount) external onlyRole(AFFILIATE) {
        _claimDirectStakingBonus(member, amount);
    }

    function claimMatchingBonus(address member, uint256 amount) external onlyRole(AFFILIATE) {
        _claimMatchingBonus(member, amount);
    }

    function getClaimedDirectStakingBonus(address member) external view returns (uint256) {
        return claimedDirectStakingBonus[member];
    }

    function getClaimedDirectBettingBonus(address member) external view returns (uint256) {
        return claimedDirectBettingBonus[member];
    }

    function getClaimedMatchingBonus(address member) external view returns (uint256) {
        return claimedMatchingBonus[member];
    }

    function _claimDirectStakingBonus(address member, uint256 amount) internal {
        claimedDirectStakingBonus[member] += amount;
    }

    function _claimDirectBettingBonus(address member, uint256 amount) internal {
        claimedDirectBettingBonus[member] += amount;
    }

    function _claimMatchingBonus(address member, uint256 amount) internal {
        claimedMatchingBonus[member] += amount;
    }

    function setAffiliate(address _affiliate) external onlyRole(TIMELOCK) {
        require(_affiliate != address(0), "AM01");
        affiliate = _affiliate;
        _grantRole(AFFILIATE, _affiliate);
    }
}
