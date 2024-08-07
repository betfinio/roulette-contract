// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin/access/AccessControl.sol";
import "./shared/staking/StakingInterface.sol";
import "./RouletteBet.sol";
import "openzeppelin/security/ReentrancyGuard.sol";
import "./shared/games/GameInterface.sol";
import "./shared/CoreInterface.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "chainlink/vrf/dev/VRFCoordinatorV2_5.sol";
import "chainlink/vrf/dev/VRFConsumerBaseV2Plus.sol";

/**
 * Errors used in this smart contract:
 * RO01 - invalid input data
 * RO02 - invalid total amount
 * RO03 - insufficient balance to cover possible win
 * RO04 - bet does not respect internal limits
 * RO05 - invalid msg sender. must be core!
 * RO06 - staking contract is not registered with Core
 */
contract Roulette is
    VRFConsumerBaseV2Plus,
    AccessControl,
    GameInterface,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    bytes32 public constant TIMELOCK = keccak256("TIMELOCK");

    uint256 public constant REQUIRED_FUNDS_COEFFICIENT = 20;
    uint256 private immutable created;
    uint64 private immutable subscriptionId;
    address public immutable vrfCoordinator;
    bytes32 public immutable keyHash;
    uint32 private constant callbackGasLimit = 2_500_000;
    uint16 public constant requestConfirmations = 3;
    uint32 private constant numWords = 1;

    StakingInterface public staking;
    CoreInterface public core;

    mapping(address => uint256[]) public playerRequests;
    mapping(uint256 => RouletteBet) public requestBets;

    struct Limit {
        uint256 min;
        uint256 max;
    }

    mapping(string => Limit) public limits;

    mapping(uint256 => uint256) public reservedFunds;

    event Rolled(
        address indexed bet,
        uint256 indexed requestId,
        address roller
    );
    event Landed(
        address indexed bet,
        uint256 indexed requestId,
        address roller,
        uint256 indexed result
    );
    event LimitChanged(
        string indexed limit,
        uint256 indexed min,
        uint256 indexed max
    );

    constructor(
        uint64 _subscriptionId,
        address _core,
        address _staking,
        address _vrfCoordinator,
        bytes32 _keyHash,
        address _admin
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        require(_vrfCoordinator != address(0), "RO01");
        vrfCoordinator = _vrfCoordinator;
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
        core = CoreInterface(_core);
        require(core.isStaking(_staking), "RO06");
        staking = StakingInterface(_staking);
        created = block.timestamp;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        limits["STRAIGHT"] = Limit(10000 ether, 150_000 ether);
        limits["TOP-LINE"] = Limit(10000 ether, 650_000 ether);
        limits["LOW-ZERO"] = Limit(10000 ether, 500_000 ether);
        limits["HIGH-ZERO"] = Limit(10000 ether, 500_000 ether);
        limits["LOW"] = Limit(20_000 ether, 3_000_000 ether);
        limits["HIGH"] = Limit(20_000 ether, 3_000_000 ether);
        limits["EVEN"] = Limit(20_000 ether, 3_000_000 ether);
        limits["ODD"] = Limit(20_000 ether, 3_000_000 ether);
        limits["RED"] = Limit(20_000 ether, 3_000_000 ether);
        limits["BLACK"] = Limit(20_000 ether, 3_000_000 ether);
        limits["1-DOZEN"] = Limit(15_000 ether, 2_000_000 ether);
        limits["2-DOZEN"] = Limit(15_000 ether, 2_000_000 ether);
        limits["3-DOZEN"] = Limit(15_000 ether, 2_000_000 ether);
        limits["1-COLUMN"] = Limit(15_000 ether, 2_000_000 ether);
        limits["2-COLUMN"] = Limit(15_000 ether, 2_000_000 ether);
        limits["3-COLUMN"] = Limit(15_000 ether, 2_000_000 ether);
        limits["CORNER"] = Limit(10000 ether, 650_000 ether);
        limits["ROW"] = Limit(10000 ether, 500_000 ether);
        limits["SPLIT"] = Limit(10000 ether, 330_000 ether);
    }

    function getPossibleWin(
        uint256[] memory data
    ) public view returns (uint256, uint256) {
        uint256 max = 0;
        uint256 winNumber = 0;
        for (uint256 value = 0; value <= 36; value++) {
            uint256 count = data.length / 2;
            uint256 possible = 0;
            for (uint256 i = 0; i < count; i++) {
                uint256 amount = data[i * 2];
                uint256 bitmap = data[i * 2 + 1];
                (uint256 payout, , ) = getBitMapPayout(bitmap);
                if (bitmap & (2 ** value) > 0) {
                    possible += amount * payout + amount;
                }
            }
            if (possible > max) {
                max = possible;
                winNumber = value;
            }
        }
        return (max, winNumber);
    }

    function roll(
        uint256 count,
        uint256 totalAmount,
        uint256[] memory data,
        address player
    ) internal nonReentrant returns (address) {
        // validate data length
        require(count * 2 == data.length, "RO01");
        // check if total amount is more that zero
        require(totalAmount > 0, "RO02");
        // validate bitmaps with limits
        validateLimits(count, data);
        // calculate max possible win
        (uint256 possibleWin, ) = getPossibleWin(data);
        // check if there is enough tokens to cover bet
        require(
            possibleWin * REQUIRED_FUNDS_COEFFICIENT <=
                IERC20(core.token()).balanceOf(address(staking)),
            "RO03"
        );
        // request random number
        uint256 requestId = VRFCoordinatorV2_5(vrfCoordinator)
            .requestRandomWords(
                VRFV2PlusClient.RandomWordsRequest({
                    keyHash: keyHash,
                    subId: subscriptionId,
                    requestConfirmations: requestConfirmations,
                    callbackGasLimit: callbackGasLimit,
                    numWords: numWords,
                    extraArgs: VRFV2PlusClient._argsToBytes(
                        VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                    )
                })
            );
        // create and register bet
        RouletteBet bet = new RouletteBet();
        bet.setPlayer(player);
        bet.setAmount(totalAmount);
        bet.setStatus(1);
        bet.setRequestId(requestId);
        bet.setGame(address(this));
        bet.setBets(count, data);
        requestBets[requestId] = bet;
        IERC20(core.token()).transfer(address(staking), totalAmount);
        playerRequests[player].push(requestId);
        emit Rolled(address(bet), requestId, player);
        // transfer required amount to roulette balance
        staking.reserveFunds(possibleWin);
        // reserve funds
        reservedFunds[requestId] = possibleWin;
        return address(bet);
    }

    function validateLimits(
        uint256 count,
        uint256[] memory data
    ) internal view {
        for (uint256 i = 0; i < count; i++) {
            uint256 amount = data[i * 2];
            uint256 bitmap = data[i * 2 + 1];
            (, uint256 min, uint256 max) = getBitMapPayout(bitmap);
            require(amount >= min && amount <= max, "RO04");
        }
    }

    function placeBet(
        address _player,
        uint256 _totalAmount,
        bytes calldata _data
    ) external returns (address betAddress) {
        require(address(core) == _msgSender(), "RO05");
        (uint256 _count, uint256[] memory _bets) = abi.decode(
            _data,
            (uint256, uint256[])
        );
        return address(roll(_count, _totalAmount, _bets, _player));
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 random = randomWords[0];
        uint256 value = (random % 37);
        RouletteBet bet = requestBets[requestId];
        address player = bet.getPlayer();
        (uint256[] memory amounts, uint256[] memory bitmaps) = bet.getBets();
        bet.setWinNumber(value);
        bet.setStatus(2);
        uint256 amount = 0;
        for (uint256 i = 0; i < bitmaps.length; i++) {
            uint256 bitmap = bitmaps[i];
            if (bitmap & (2 ** value) > 0) {
                (uint256 payout, , ) = getBitMapPayout(bitmap);
                amount += amounts[i] * payout + amounts[i];
            }
        }
        bet.setResult(amount);
        if (amount > 0) {
            // send win amount ot player
            IERC20(core.token()).transfer(player, amount);
        }
        // send leftovers back to staking contract
        IERC20(core.token()).transfer(
            address(staking),
            reservedFunds[requestId] - amount
        );
        // clear reserved funds for current request
        reservedFunds[requestId] = 0;
        emit Landed(address(bet), requestId, player, value);
    }

    function getBitMapPayout(
        uint256 bitmap
    ) public view returns (uint256, uint256, uint256) {
        // return invalid bitmap
        if (bitmap == 0) return (0, 0, 0);
        // check for TOP LINE 0,1,2,3
        if (bitmap == 15)
            return (8, limits["TOP-LINE"].min, limits["TOP-LINE"].max);
        // check for LOW ZERO 0,1,2
        if (bitmap == 7)
            return (11, limits["LOW-ZERO"].min, limits["LOW-ZERO"].max);
        // check for HIGH ZERO 0,2,3
        if (bitmap == 13)
            return (11, limits["HIGH-ZERO"].min, limits["HIGH-ZERO"].max);
        // check for LOW 1-18
        if (bitmap == 524286) return (1, limits["LOW"].min, limits["LOW"].max);
        // check for HIGH 19-36
        if (bitmap == 137438429184)
            return (1, limits["HIGH"].min, limits["HIGH"].max);
        // check for EVEN
        if (bitmap == 91625968980)
            return (1, limits["EVEN"].min, limits["EVEN"].max);
        // check for ODD
        if (bitmap == 45812984490)
            return (1, limits["ODD"].min, limits["ODD"].max);
        // check for RED
        if (bitmap == 91447186090)
            return (1, limits["RED"].min, limits["RED"].max);
        // check for BLACK
        if (bitmap == 45991767380)
            return (1, limits["BLACK"].min, limits["BLACK"].max);
        // check for 1-dozen
        if (bitmap == 8190)
            return (2, limits["1-DOZEN"].min, limits["1-DOZEN"].max);
        // check for 2-dozen
        if (bitmap == 33546240)
            return (2, limits["2-DOZEN"].min, limits["2-DOZEN"].max);
        // check for 3-dozen
        if (bitmap == 137405399040)
            return (2, limits["3-DOZEN"].min, limits["3-DOZEN"].max);
        // check for 1-column
        if (bitmap == 78536544840)
            return (2, limits["1-COLUMN"].min, limits["1-COLUMN"].max);
        // check for 2-column
        if (bitmap == 39268272420)
            return (2, limits["2-COLUMN"].min, limits["2-COLUMN"].max);
        // check for 3-column
        if (bitmap == 19634136210)
            return (2, limits["3-COLUMN"].min, limits["3-COLUMN"].max);
        // check for straight 0,1,2,3...36
        if (bitmap & (bitmap - 1) == 0)
            return (35, limits["STRAIGHT"].min, limits["STRAIGHT"].max);
        // check for corner
        if (isCorner(bitmap))
            return (8, limits["CORNER"].min, limits["CORNER"].max);
        // check for row
        if (isRow(bitmap)) return (11, limits["ROW"].min, limits["ROW"].max);
        // check for split
        if (isSplit(bitmap))
            return (17, limits["SPLIT"].min, limits["SPLIT"].max);
        return (0, 0, 0);
    }

    function getPlayerRequestsCount(
        address player
    ) public view returns (uint256) {
        return playerRequests[player].length;
    }

    function getRequestBet(uint256 requestId) public view returns (address) {
        return address(requestBets[requestId]);
    }

    function getAddress() public view override returns (address) {
        return address(this);
    }

    function getVersion() public view override returns (uint256) {
        return created;
    }

    function getFeeType() public pure override returns (uint256) {
        return 1;
    }

    function getStaking() public view override returns (address) {
        return address(staking);
    }

    function setLimit(
        string calldata limit,
        uint256 min,
        uint256 max
    ) public onlyRole(TIMELOCK) {
        limits[limit] = Limit(min, max);
        emit LimitChanged(limit, min, max);
    }

    function isRow(uint256 bitmap) public pure returns (bool) {
        // check 1,2,3
        if (bitmap == 14) return true;
        // check 4,5,6
        if (bitmap == 112) return true;
        // check 7,8,9
        if (bitmap == 896) return true;
        // check 10,11,12
        if (bitmap == 7168) return true;
        // check 13,14,15
        if (bitmap == 57344) return true;
        // check 16,17,18
        if (bitmap == 458752) return true;
        // check 19,20,21
        if (bitmap == 3670016) return true;
        // check 22,23,24
        if (bitmap == 29360128) return true;
        // check 25,26,27
        if (bitmap == 234881024) return true;
        // check 28,29,30
        if (bitmap == 1879048192) return true;
        // check 31,32,33
        if (bitmap == 15032385536) return true;
        // check 34,35,36
        if (bitmap == 120259084288) return true;
        return false;
    }

    function isCorner(uint256 bitmap) public pure returns (bool) {
        // check 1,2,4,5
        if (bitmap == 54) return true;
        // check 2,3,5,6
        if (bitmap == 108) return true;
        // check 4,5,7,8
        if (bitmap == 432) return true;
        // check 5,6,8,9
        if (bitmap == 864) return true;
        // check 7,8,10,11
        if (bitmap == 3456) return true;
        // check 8,9,11,12
        if (bitmap == 6912) return true;
        // check 10,11,13,14
        if (bitmap == 27648) return true;
        // check 11,12,14,15
        if (bitmap == 55296) return true;
        // check 13,14,16,17
        if (bitmap == 221184) return true;
        // check 14,15,17,18
        if (bitmap == 442368) return true;
        // check 16,17,19,20
        if (bitmap == 1769472) return true;
        // check 17,18,20,21
        if (bitmap == 3538944) return true;
        // check 19,20,22,23
        if (bitmap == 14155776) return true;
        // check 20,21,23,24
        if (bitmap == 28311552) return true;
        // check 22,23,25,26
        if (bitmap == 113246208) return true;
        // check 23,24,26,27
        if (bitmap == 226492416) return true;
        // check 25,26,28,29
        if (bitmap == 905969664) return true;
        // check 26,27,29,30
        if (bitmap == 1811939328) return true;
        // check 28,29,31,32
        if (bitmap == 7247757312) return true;
        // check 29,30,32,33
        if (bitmap == 14495514624) return true;
        // check 31,32,34,35
        if (bitmap == 57982058496) return true;
        // check 32,33,35,36
        if (bitmap == 115964116992) return true;
        return false;
    }

    function isSplit(uint256 bitmap) public pure returns (bool) {
        uint256[60] memory splits = [
            3,
            5,
            9,
            6,
            12,
            18,
            36,
            48,
            72,
            96,
            144,
            288,
            384,
            576,
            768,
            1152,
            2304,
            3072,
            4608,
            6144,
            9216,
            18432,
            24576,
            36864,
            49152,
            73728,
            147456,
            196608,
            294912,
            393216,
            589824,
            1179648,
            1572864,
            2359296,
            3145728,
            4718592,
            9437184,
            12582912,
            18874368,
            25165824,
            37748736,
            75497472,
            100663296,
            150994944,
            201326592,
            301989888,
            603979776,
            805306368,
            1207959552,
            1610612736,
            2415919104,
            4831838208,
            6442450944,
            9663676416,
            12884901888,
            19327352832,
            38654705664,
            51539607552,
            77309411328,
            uint256(103079215104)
        ];
        for (uint256 i = 0; i < splits.length; i++) {
            if (bitmap == splits[i]) return true;
        }
        return false;
    }
}
