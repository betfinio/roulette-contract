// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/security/ReentrancyGuard.sol";
import "./affiliate/AffiliateMember.sol";
import "./affiliate/AffiliateInterface.sol";

/**
 * Errors used in this contract
 *
 * PS01 - account already owns pass
 * PS02 - inviter is not a member
 * PS03 - inviter did not met requirements
 * PS04 - parent is not a member
 * PS05 - pass is not transferable
 * PS06 - inviter disabled mint
 * PS07 - not a member
 */
contract Pass is ERC721, AffiliateMember, ReentrancyGuard {
    mapping(address => bool) public mintDisabled;

    constructor(address admin) ERC721("BetFin Pass", "Pass") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function mint(address member, address inviter, address parent) external nonReentrant {
        if (getMembersCount() > 0) {
            // revert if account already owns pass
            require(!isMember[member] && balanceOf(member) == 0, "PS01");
            // revert if inviter is not a member
            require(isMember[inviter] && balanceOf(inviter) > 0, "PS02");
            // revert if inviter disabled mint
            require(mintDisabled[inviter] == false, "PS06");
            // revert if inviter did not met requirements
            require(AffiliateInterface(affiliate).checkInviteCondition(inviter), "PS03");
            // revert if parent is not a member
            require(isMember[parent] && balanceOf(parent) > 0, "PS04");
        }
        // safely mint
        super._safeMint(member, membersCount + 1);
        // push to affiliate tree
        super._push(member, inviter);
        // emit event
        emit NewMember(member, inviter, parent);
    }

    function transferFrom(address, address, uint256) public view override {
        // transferring is forbidden
        require(block.number == 0, "PS05");
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function disableMint() public {
        require(balanceOf(_msgSender()) > 0, "PS07");
        mintDisabled[_msgSender()] = true;
    }

    function enableMint() public {
        require(balanceOf(_msgSender()) > 0, "PS07");
        mintDisabled[_msgSender()] = false;
    }
}
