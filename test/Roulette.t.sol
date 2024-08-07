// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "../src/Roulette.sol";
import "../src/shared/Token.sol";
import "../src/shared/Core.sol";
import "./DynamicStakingMock.sol";

contract RouletteTest is Test {
    Roulette public roulette;
    Core public core;
    Token public token;
    Pass public pass;
    BetsMemory public betsMemory;
    DynamicStakingMock public staking;
    Partner public partner;
    address public alice = address(1);

    function setUpCore() public {
        token = new Token(address(this));
        betsMemory = new BetsMemory(address(this));
        pass = new Pass(address(this));
        betsMemory.grantRole(betsMemory.TIMELOCK(), address(this));
        betsMemory.setPass(address(pass));
        pass.mint(alice, address(0), address(0));
        core = new Core(
            address(token),
            address(betsMemory),
            address(pass),
            address(this)
        );
        betsMemory.addAggregator(address(core));
        token.transfer(address(core), 1_000_000 ether);
        core.grantRole(core.TIMELOCK(), address(this));
        address tar = core.addTariff(0, 1_00, 0);
        partner = Partner(core.addPartner(tar));
    }

    function setUp() public {
        setUpCore();
        staking = new DynamicStakingMock(address(token));
        core.addStaking(address(staking));
        roulette = new Roulette(
            555,
            address(core),
            address(staking),
            0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed,
            0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f,
            address(this)
        );
        core.grantRole(core.TIMELOCK(), address(this));
        core.addGame(address(roulette));
        staking.grantRole(staking.TIMELOCK(), address(this));
        staking.addGame(address(roulette));
        token.transfer(address(staking), 1_000_000 ether);
        token.transfer(address(alice), 100 ether);
        vm.startPrank(alice);
        token.approve(address(core), 100 ether);
        vm.stopPrank();
        vm.mockCall(
            address(pass),
            abi.encodeWithSelector(
                AffiliateMember.getInviter.selector,
                address(0)
            ),
            abi.encode(address(1))
        );
    }

    function testOdd() public {
        roulette.grantRole(roulette.TIMELOCK(), address(this));
        roulette.setLimit("ODD", 10 ether, 10000000 ether);
        vm.startPrank(alice);
        uint256[] memory bets = new uint256[](2);
        bets[0] = 10 ether;
        bets[1] = 45812984490;
        vm.mockCall(
            0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed,
            abi.encodeWithSelector(
                VRFCoordinatorV2_5.requestRandomWords.selector,
                VRFV2PlusClient.RandomWordsRequest({
                    keyHash: bytes32(
                        0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f
                    ),
                    subId: uint256(555),
                    requestConfirmations: uint16(3),
                    callbackGasLimit: uint32(2_500_000),
                    numWords: uint32(1),
                    extraArgs: VRFV2PlusClient._argsToBytes(
                        VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                    )
                })
            ),
            abi.encode(uint256(999))
        );
        address bet = partner.placeBet(
            address(roulette),
            10 ether,
            abi.encode(uint256(1), bets)
        );
        assertEq(RouletteBet(bet).getStatus(), 1);
        assertEq(token.balanceOf(address(staking)), 999_990 ether);
        uint256[] memory result = new uint256[](1);
        result[0] = 7;
        vm.stopPrank();
        vm.startPrank(roulette.vrfCoordinator());
        roulette.rawFulfillRandomWords(RouletteBet(bet).getRequestId(), result);
        vm.stopPrank();
        assertEq(RouletteBet(bet).getStatus(), 2);
        assertEq(token.balanceOf(address(staking)), 999_990 ether);
        assertEq(token.balanceOf(address(roulette)), 0 ether);
        assertEq(token.balanceOf(alice), 110 ether);
    }

    function testInsufficientFunds() public {
        token.transfer(address(alice), 100000 ether);
        vm.startPrank(alice);
        token.approve(address(core), 100000 ether);
        vm.stopPrank();
        // try to make a bet
        vm.startPrank(alice);
        uint256[] memory bets = new uint256[](2);
        bets[0] = 100000 ether;
        bets[1] = 45812984490;
        vm.expectRevert(bytes("RO03"));
        partner.placeBet(
            address(roulette),
            100000 ether,
            abi.encode(uint256(1), bets)
        );
    }

    function testEven() public {
        roulette.grantRole(roulette.TIMELOCK(), address(this));
        roulette.setLimit("EVEN", 10 ether, 10000000 ether);
        vm.startPrank(alice);
        uint256[] memory bets = new uint256[](2);
        bets[0] = 10 ether;
        bets[1] = 91625968980;
        vm.mockCall(
            0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed,
            abi.encodeWithSelector(
                VRFCoordinatorV2_5.requestRandomWords.selector,
                VRFV2PlusClient.RandomWordsRequest({
                    keyHash: bytes32(
                        0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f
                    ),
                    subId: uint256(555),
                    requestConfirmations: uint16(3),
                    callbackGasLimit: uint32(2_500_000),
                    numWords: uint32(1),
                    extraArgs: VRFV2PlusClient._argsToBytes(
                        VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                    )
                })
            ),
            abi.encode(uint256(999))
        );
        address bet = partner.placeBet(
            address(roulette),
            10 ether,
            abi.encode(uint256(1), bets)
        );
        assertEq(token.balanceOf(address(staking)), 999_990 ether);
        assertEq(token.balanceOf(alice), 90 ether);
        assertEq(RouletteBet(bet).getStatus(), 1);
        uint256[] memory result = new uint256[](1);
        result[0] = 32;
        vm.startPrank(roulette.vrfCoordinator());
        roulette.rawFulfillRandomWords(RouletteBet(bet).getRequestId(), result);
        vm.stopPrank();
        assertEq(RouletteBet(bet).getStatus(), 2);
        assertEq(token.balanceOf(address(staking)), 999_990 ether);
        assertEq(token.balanceOf(address(roulette)), 0 ether);
        assertEq(token.balanceOf(alice), 110 ether);
    }

    function getCombination(
        uint256[] memory numbers
    ) internal pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < numbers.length; i++) {
            if (numbers[i] > 36) {
                result += 0;
            } else {
                result += 2 ** numbers[i];
            }
        }
        return result;
    }

    function testEveryStraightCombinations() public {
        roulette.grantRole(roulette.TIMELOCK(), address(this));
        roulette.setLimit("STRAIGHT", 10 ether, 10000000 ether);
        token.transfer(address(alice), 27 * 10 ether);
        vm.startPrank(alice);
        token.approve(address(core), 37 * 10 ether);
        uint256[] memory bets = new uint256[](74);
        uint256[] memory combs = new uint256[](1);
        // 0
        bets[0] = 10 ether;
        combs[0] = 0;
        bets[1] = getCombination(combs);
        // 1
        bets[2] = 10 ether;
        combs[0] = 1;
        bets[3] = getCombination(combs);
        // 2
        bets[4] = 10 ether;
        combs[0] = 2;
        bets[5] = getCombination(combs);
        // 3
        bets[6] = 10 ether;
        combs[0] = 3;
        bets[7] = getCombination(combs);
        // 4
        bets[8] = 10 ether;
        combs[0] = 4;
        bets[9] = getCombination(combs);
        // 5
        bets[10] = 10 ether;
        combs[0] = 5;
        bets[11] = getCombination(combs);
        // 6
        bets[12] = 10 ether;
        combs[0] = 6;
        bets[13] = getCombination(combs);
        // 7
        bets[14] = 10 ether;
        combs[0] = 7;
        bets[15] = getCombination(combs);
        // 8
        bets[16] = 10 ether;
        combs[0] = 8;
        bets[17] = getCombination(combs);
        // 9
        bets[18] = 10 ether;
        combs[0] = 9;
        bets[19] = getCombination(combs);
        // 10
        bets[20] = 10 ether;
        combs[0] = 10;
        bets[21] = getCombination(combs);

        // 11
        bets[22] = 10 ether;
        combs[0] = 11;
        bets[23] = getCombination(combs);

        // 12
        bets[24] = 10 ether;
        combs[0] = 12;
        bets[25] = getCombination(combs);

        // 13
        bets[26] = 10 ether;
        combs[0] = 13;
        bets[27] = getCombination(combs);

        // 14
        bets[28] = 10 ether;
        combs[0] = 14;
        bets[29] = getCombination(combs);

        // 15
        bets[30] = 10 ether;
        combs[0] = 15;
        bets[31] = getCombination(combs);

        // 16
        bets[32] = 10 ether;
        combs[0] = 16;
        bets[33] = getCombination(combs);

        // 17
        bets[34] = 10 ether;
        combs[0] = 17;
        bets[35] = getCombination(combs);

        // 18
        bets[36] = 10 ether;
        combs[0] = 18;
        bets[37] = getCombination(combs);

        // 19
        bets[38] = 10 ether;
        combs[0] = 19;
        bets[39] = getCombination(combs);

        // 20
        bets[40] = 10 ether;
        combs[0] = 20;
        bets[41] = getCombination(combs);

        // 21
        bets[42] = 10 ether;
        combs[0] = 21;
        bets[43] = getCombination(combs);

        // 22
        bets[44] = 10 ether;
        combs[0] = 22;
        bets[45] = getCombination(combs);

        // 23
        bets[46] = 10 ether;
        combs[0] = 23;
        bets[47] = getCombination(combs);

        // 24
        bets[48] = 10 ether;
        combs[0] = 24;
        bets[49] = getCombination(combs);

        // 25
        bets[50] = 10 ether;
        combs[0] = 25;
        bets[51] = getCombination(combs);

        // 26
        bets[52] = 10 ether;
        combs[0] = 26;
        bets[53] = getCombination(combs);

        // 27
        bets[54] = 10 ether;
        combs[0] = 27;
        bets[55] = getCombination(combs);

        // 28
        bets[56] = 10 ether;
        combs[0] = 28;
        bets[57] = getCombination(combs);

        // 29
        bets[58] = 10 ether;
        combs[0] = 29;
        bets[59] = getCombination(combs);

        // 30
        bets[60] = 10 ether;
        combs[0] = 30;
        bets[61] = getCombination(combs);

        // 31
        bets[62] = 10 ether;
        combs[0] = 31;
        bets[63] = getCombination(combs);

        // 32
        bets[64] = 10 ether;
        combs[0] = 32;
        bets[65] = getCombination(combs);

        // 33
        bets[66] = 10 ether;
        combs[0] = 33;
        bets[67] = getCombination(combs);

        // 34
        bets[68] = 10 ether;
        combs[0] = 34;
        bets[69] = getCombination(combs);

        // 35
        bets[70] = 10 ether;
        combs[0] = 35;
        bets[71] = getCombination(combs);

        // 36
        bets[72] = 10 ether;
        combs[0] = 36;
        bets[73] = getCombination(combs);

        vm.mockCall(
            0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed,
            abi.encodeWithSelector(
                VRFCoordinatorV2_5.requestRandomWords.selector,
                VRFV2PlusClient.RandomWordsRequest({
                    keyHash: bytes32(
                        0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f
                    ),
                    subId: uint256(555),
                    requestConfirmations: uint16(3),
                    callbackGasLimit: uint32(2_500_000),
                    numWords: uint32(1),
                    extraArgs: VRFV2PlusClient._argsToBytes(
                        VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                    )
                })
            ),
            abi.encode(uint256(999))
        );
        address bet = partner.placeBet(
            address(roulette),
            37 * 10 ether,
            abi.encode(uint256(37), bets)
        );
        assertEq(token.balanceOf(address(staking)), 1_000_010 ether);
        assertEq(token.balanceOf(address(roulette)), 360 ether);
        assertEq(token.balanceOf(alice), 0 ether);
        assertEq(RouletteBet(bet).getStatus(), 1);
        uint256[] memory result = new uint256[](1);
        result[0] = 0;
        vm.startPrank(roulette.vrfCoordinator());
        roulette.rawFulfillRandomWords(RouletteBet(bet).getRequestId(), result);
        vm.stopPrank();
        assertEq(RouletteBet(bet).getStatus(), 2);
        assertEq(token.balanceOf(address(staking)), 1_000_010 ether);
        assertEq(token.balanceOf(address(roulette)), 0 ether);
        assertEq(token.balanceOf(alice), 36 * 10 ether);
    }

    function testEveryRowCombinations() public {
        roulette.grantRole(roulette.TIMELOCK(), address(this));
        roulette.setLimit("ROW", 10 ether, 10000000 ether);
        token.transfer(address(alice), 2 * 10 ether);
        vm.startPrank(alice);
        token.approve(address(core), 12 * 10 ether);
        uint256[] memory bets = new uint256[](24);
        uint256[] memory combs = new uint256[](3);
        // 1,2,3
        bets[0] = 10 ether;
        combs[0] = 1;
        combs[1] = 2;
        combs[2] = 3;
        bets[1] = getCombination(combs);

        // 4,5,6
        bets[2] = 10 ether;
        combs[0] = 4;
        combs[1] = 5;
        combs[2] = 6;
        bets[3] = getCombination(combs);

        // 7,8,9
        bets[4] = 10 ether;
        combs[0] = 7;
        combs[1] = 8;
        combs[2] = 9;
        bets[5] = getCombination(combs);

        // 10,11,12
        bets[6] = 10 ether;
        combs[0] = 10;
        combs[1] = 11;
        combs[2] = 12;
        bets[7] = getCombination(combs);

        // 13,14,15
        bets[8] = 10 ether;
        combs[0] = 13;
        combs[1] = 14;
        combs[2] = 15;
        bets[9] = getCombination(combs);

        // 16,17,18
        bets[10] = 10 ether;
        combs[0] = 16;
        combs[1] = 17;
        combs[2] = 18;
        bets[11] = getCombination(combs);

        // 19,20,21
        bets[12] = 10 ether;
        combs[0] = 19;
        combs[1] = 20;
        combs[2] = 21;
        bets[13] = getCombination(combs);

        // 22,23,24
        bets[14] = 10 ether;
        combs[0] = 22;
        combs[1] = 23;
        combs[2] = 24;
        bets[15] = getCombination(combs);

        // 25,26,27
        bets[16] = 10 ether;
        combs[0] = 25;
        combs[1] = 26;
        combs[2] = 27;
        bets[17] = getCombination(combs);

        // 28,29,30
        bets[18] = 10 ether;
        combs[0] = 28;
        combs[1] = 29;
        combs[2] = 30;
        bets[19] = getCombination(combs);

        // 31,32,33
        bets[20] = 10 ether;
        combs[0] = 31;
        combs[1] = 32;
        combs[2] = 33;
        bets[21] = getCombination(combs);

        // 34,35,36
        bets[22] = 10 ether;
        combs[0] = 34;
        combs[1] = 35;
        combs[2] = 36;
        bets[23] = getCombination(combs);

        vm.mockCall(
            0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed,
            abi.encodeWithSelector(
                VRFCoordinatorV2_5.requestRandomWords.selector,
                VRFV2PlusClient.RandomWordsRequest({
                    keyHash: bytes32(
                        0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f
                    ),
                    subId: uint256(555),
                    requestConfirmations: uint16(3),
                    callbackGasLimit: uint32(2_500_000),
                    numWords: uint32(1),
                    extraArgs: VRFV2PlusClient._argsToBytes(
                        VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                    )
                })
            ),
            abi.encode(uint256(999))
        );
        address bet = partner.placeBet(
            address(roulette),
            12 * 10 ether,
            abi.encode(uint256(12), bets)
        );
        assertEq(token.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(token.balanceOf(alice), 0 ether);
        assertEq(RouletteBet(bet).getStatus(), 1);
        uint256[] memory result = new uint256[](1);
        result[0] = 7;
        vm.startPrank(roulette.vrfCoordinator());
        roulette.rawFulfillRandomWords(RouletteBet(bet).getRequestId(), result);
        vm.stopPrank();
        assertEq(RouletteBet(bet).getStatus(), 2);
        assertEq(token.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(token.balanceOf(address(roulette)), 0 ether);
        assertEq(token.balanceOf(alice), 12 * 10 ether);
    }

    function testEveryColumnCombinations() public {
        roulette.grantRole(roulette.TIMELOCK(), address(this));
        roulette.setLimit("3-COLUMN", 10 ether, 10000000 ether);
        roulette.setLimit("1-COLUMN", 10 ether, 10000000 ether);
        roulette.setLimit("2-COLUMN", 10 ether, 10000000 ether);
        vm.startPrank(alice);
        uint256[] memory bets = new uint256[](6);
        uint256[] memory combs = new uint256[](12);
        // 1-column
        bets[0] = 10 ether;
        combs[0] = 1;
        combs[1] = 4;
        combs[2] = 7;
        combs[3] = 10;
        combs[4] = 13;
        combs[5] = 16;
        combs[6] = 19;
        combs[7] = 22;
        combs[8] = 25;
        combs[9] = 28;
        combs[10] = 31;
        combs[11] = 34;
        bets[1] = getCombination(combs);
        // 2-column
        bets[2] = 10 ether;
        combs[0] = 2;
        combs[1] = 5;
        combs[2] = 8;
        combs[3] = 11;
        combs[4] = 14;
        combs[5] = 17;
        combs[6] = 20;
        combs[7] = 23;
        combs[8] = 26;
        combs[9] = 29;
        combs[10] = 32;
        combs[11] = 35;
        bets[3] = getCombination(combs);
        // 3-column
        bets[4] = 10 ether;
        combs[0] = 3;
        combs[1] = 6;
        combs[2] = 9;
        combs[3] = 12;
        combs[4] = 15;
        combs[5] = 18;
        combs[6] = 21;
        combs[7] = 24;
        combs[8] = 27;
        combs[9] = 30;
        combs[10] = 33;
        combs[11] = 36;
        bets[5] = getCombination(combs);

        vm.mockCall(
            0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed,
            abi.encodeWithSelector(
                VRFCoordinatorV2_5.requestRandomWords.selector,
                VRFV2PlusClient.RandomWordsRequest({
                    keyHash: bytes32(
                        0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f
                    ),
                    subId: uint256(555),
                    requestConfirmations: uint16(3),
                    callbackGasLimit: uint32(2_500_000),
                    numWords: uint32(1),
                    extraArgs: VRFV2PlusClient._argsToBytes(
                        VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                    )
                })
            ),
            abi.encode(uint256(999))
        );
        address bet = partner.placeBet(
            address(roulette),
            3 * 10 ether,
            abi.encode(uint256(3), bets)
        );
        assertEq(token.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(token.balanceOf(alice), 70 ether);
        assertEq(RouletteBet(bet).getStatus(), 1);
        uint256[] memory result = new uint256[](1);
        result[0] = 7;
        vm.startPrank(roulette.vrfCoordinator());
        roulette.rawFulfillRandomWords(RouletteBet(bet).getRequestId(), result);
        vm.stopPrank();
        assertEq(RouletteBet(bet).getStatus(), 2);
        assertEq(token.balanceOf(address(staking)), 1_000_000 ether);
        assertEq(token.balanceOf(alice), 10 * 10 ether);
    }

    function testSimRolls() public {
        roulette.grantRole(roulette.TIMELOCK(), address(this));
        roulette.setLimit("STRAIGHT", 10 ether, 10000000 ether);
        uint256[] memory bets1 = new uint256[](4);
        uint256[] memory bets2 = new uint256[](4);
        uint256[] memory combs = new uint256[](1);
        // 15
        bets1[0] = 10 ether;
        combs[0] = 15;
        bets1[1] = getCombination(combs);
        // 19
        bets1[2] = 10 ether;
        combs[0] = 19;
        bets1[3] = getCombination(combs);
        // 4
        bets2[0] = 10 ether;
        combs[0] = 4;
        bets2[1] = getCombination(combs);
        // 36
        bets2[2] = 10 ether;
        combs[0] = 36;
        bets2[3] = getCombination(combs);
        vm.startPrank(alice);

        vm.mockCall(
            0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed,
            abi.encodeWithSelector(
                VRFCoordinatorV2_5.requestRandomWords.selector,
                VRFV2PlusClient.RandomWordsRequest({
                    keyHash: bytes32(
                        0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f
                    ),
                    subId: uint256(555),
                    requestConfirmations: uint16(3),
                    callbackGasLimit: uint32(2_500_000),
                    numWords: uint32(1),
                    extraArgs: VRFV2PlusClient._argsToBytes(
                        VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                    )
                })
            ),
            abi.encode(uint256(999))
        );
        address bet1 = partner.placeBet(
            address(roulette),
            20 ether,
            abi.encode(uint256(2), bets1)
        );
        vm.mockCall(
            0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed,
            abi.encodeWithSelector(
                VRFCoordinatorV2_5.requestRandomWords.selector,
                VRFV2PlusClient.RandomWordsRequest({
                    keyHash: bytes32(
                        0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f
                    ),
                    subId: uint256(555),
                    requestConfirmations: uint16(3),
                    callbackGasLimit: uint32(2_500_000),
                    numWords: uint32(1),
                    extraArgs: VRFV2PlusClient._argsToBytes(
                        VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                    )
                })
            ),
            abi.encode(uint256(777))
        );
        address bet2 = partner.placeBet(
            address(roulette),
            20 ether,
            abi.encode(uint256(2), bets2)
        );
        assertEq(RouletteBet(bet1).getRequestId(), 999);
        assertEq(RouletteBet(bet2).getRequestId(), 777);
        assertEq(token.balanceOf(address(staking)), 999320 ether);
        assertEq(token.balanceOf(address(roulette)), 720 ether);
        uint256[] memory result1 = new uint256[](1);
        result1[0] = 17;
        vm.startPrank(roulette.vrfCoordinator());
        roulette.rawFulfillRandomWords(999, result1);
        vm.stopPrank();
        assertEq(token.balanceOf(address(staking)), 999680 ether);
        assertEq(token.balanceOf(address(roulette)), 360 ether);
        assertEq(token.balanceOf(address(alice)), 60 ether);
        uint256[] memory result2 = new uint256[](1);
        result2[0] = 36;
        vm.startPrank(roulette.vrfCoordinator());
        roulette.rawFulfillRandomWords(777, result2);
        vm.stopPrank();
        assertEq(token.balanceOf(address(staking)), 999680 ether);
        assertEq(token.balanceOf(address(roulette)), 0 ether);
        assertEq(token.balanceOf(address(alice)), 420 ether);
    }
}
