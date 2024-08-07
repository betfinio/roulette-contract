// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface StakingInterface {
    function getAddress() external view returns (address);

    function getToken() external view returns (address);

    function stake(address staker, uint256 amount) external;

    function getStaked(address staker) external view returns (uint256);

    function totalStaked() external view returns (uint256);

    function totalStakers() external view returns (uint256);

    function reserveFunds(uint256 amount) external;
}
