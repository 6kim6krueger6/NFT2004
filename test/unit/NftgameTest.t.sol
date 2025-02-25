//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {NFTgame} from "src/NFTgame.sol";
import {NFT} from "src/NFT.sol";
import {VRFCoordinatorV2_5Mock} from
    "chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract NFTgameTest is Test {
    NFT public nft;
    NFTgame public nftgame;
    VRFCoordinatorV2_5Mock public vrfCoordinator;
    uint256 subId;

    address USER1 = makeAddr("user1");
    address USER2 = makeAddr("user2");
    address USER3 = makeAddr("user3");

    uint96 public baseFee = 0.1 ether;
    uint96 public gasPrice = 20 gwei;
    int256 public weiPerUnitLink = 0.0005 ether;

    function setUp() public {
        vrfCoordinator = new VRFCoordinatorV2_5Mock(baseFee, gasPrice, weiPerUnitLink);
        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, 1000 ether);
        nft = new NFT(address(vrfCoordinator), subId);
        vrfCoordinator.addConsumer(subId, address(nft));
        nftgame = new NFTgame(address(nft), address(vrfCoordinator), subId);
        vrfCoordinator.addConsumer(subId, address(nftgame));
        vm.deal(USER1, 1 ether);
        vm.deal(USER2, 1 ether);
        vm.deal(USER3, 1 ether);
    }

    modifier user1Minted() {
        vm.startPrank(USER1);
        nft.safeMint{value: 0.01 ether}();
        uint256 requestId = nft.getLatestRequestId();
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 1234533331133333311 % 1000;
        vrfCoordinator.fulfillRandomWords(requestId, address(nft));
        _;
    }

    function testStartRevertsIfNotOwner() public {
        vm.startPrank(USER1);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));
        nftgame.startTheGame(1);
    }

    function testStartRevertsIfGameAlreadyStarted() public user1Minted {
        nftgame.startTheGame(0);
        vm.startPrank(USER2);
        nft.safeMint{value: 0.01 ether}();
        uint256 requestId1 = nft.getLatestRequestId();
        uint256[] memory randomWords1 = new uint256[](1);
        randomWords1[0] = 1234533331133332211 % 1000;
        vrfCoordinator.fulfillRandomWords(requestId1, address(nft));
        vm.expectRevert(NFTgame.GameIsNotOpen.selector);
        nftgame.startTheGame(1);
        vm.stopPrank();
    }

    function testJoinRevertsifGameAlreadyStarted() public user1Minted {
        nftgame.startTheGame(0);
        vm.startPrank(USER2);
        nft.safeMint{value: 0.01 ether}();
        uint256 requestId1 = nft.getLatestRequestId();
        uint256[] memory randomWords1 = new uint256[](1);
        randomWords1[0] = 1234533331133332211 % 1000;
        vrfCoordinator.fulfillRandomWords(requestId1, address(nft));
        nftgame.joinTheGame(1, 1);

        vm.startPrank(USER3);
        nft.safeMint{value: 0.01 ether}();
        uint256 requestId2 = nft.getLatestRequestId();
        uint256[] memory randomWords2 = new uint256[](1);
        randomWords2[0] = 1234533331133332211 % 1000;
        vrfCoordinator.fulfillRandomWords(requestId2, address(nft));
        vm.expectRevert(NFTgame.GameIsFull.selector);
        nftgame.joinTheGame(1, 2);
        vm.stopPrank();
    }

    modifier twoUsersMinted() {
        // Минт NFT для USER1
        vm.startPrank(USER1);
        nft.safeMint{value: 0.01 ether}();
        uint256 requestId1 = nft.getLatestRequestId();
        uint256[] memory randomWords1 = new uint256[](1);
        randomWords1[0] = 1234533331133333311 % 1000; // Пример случайного числа
        vrfCoordinator.fulfillRandomWords(requestId1, address(nft));
        vm.stopPrank();

        // Минт NFT для USER2
        vm.startPrank(USER2);
        nft.safeMint{value: 0.01 ether}();
        uint256 requestId2 = nft.getLatestRequestId();
        uint256[] memory randomWords2 = new uint256[](1);
        randomWords2[0] = 1234533331133132211 % 1000; // Пример случайного числа
        vrfCoordinator.fulfillRandomWords(requestId2, address(nft));
        vm.stopPrank();

        _;
    }


    function testGameOutcome() public twoUsersMinted {
    // Начинаем игру от имени USER1
    vm.startPrank(USER1);
    uint256 tokenId1 = 0; // Предположим, что USER1 получил токен с ID 0
    nft.approve(address(nftgame), tokenId1); // Разрешение на передачу токена
    nftgame.startTheGame(tokenId1);
    vm.stopPrank();

    // USER2 присоединяется к игре
    vm.startPrank(USER2);
    uint256 tokenId2 = 1; // Предположим, что USER2 получил токен с ID 1
    nft.approve(address(nftgame), tokenId2); // Разрешение на передачу токена
    nftgame.joinTheGame(1, tokenId2);
    vm.stopPrank();

    // Симулируем получение случайных чисел от Chainlink VRF
    uint256[] memory randomWords = new uint256[](2);
    randomWords[0] = 500; // Случайное число для USER1
    randomWords[1] = 700; // Случайное число для USER2

    // Вызываем fulfillRandomWords для обоих запросов
    uint256[] memory requestIds = nftgame.getGameRequests(1);
    vrfCoordinator.fulfillRandomWords(requestIds[0], address(nftgame));
    vrfCoordinator.fulfillRandomWords(requestIds[1], address(nftgame));

    // Проверяем, что USER2 выиграл и получил NFT от USER1
    assertEq(nft.ownerOf(tokenId1), USER2, "USER2 should own USER1's NFT after winning");
    assertEq(nft.ownerOf(tokenId2), USER2, "USER2 should still own their own NFT");

    // Проверяем, что событие GameResult было вызвано с правильными параметрами
    vm.expectEmit(true, true, true, true);
    emit NFTgame.GameResult(USER2, 1, true);

    // Проверяем, что игра завершена
    (, , , , , , , bool fulfilled, , , ) = nftgame.getGame(1);
    assertTrue(fulfilled, "Game should be fulfilled");
}
}
