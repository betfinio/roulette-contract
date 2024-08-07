// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface AffiliateInterface {
    function checkInviteCondition(address inviter) external view returns (bool);

    function getMatchingBonus(address member) external view returns (uint256);

    function getConservativeStaking() external view returns (address);

    function getDynamicStaking() external view returns (address);

    function getBetsMemory() external view returns (address);

    function getPass() external view returns (address);
}
