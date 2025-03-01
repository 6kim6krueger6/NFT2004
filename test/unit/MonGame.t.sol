//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {RPSgame} from "../../src/MonGame.sol";
import {Monad} from "../../src/Monad.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract MonGameTest is Test {
    RPSgame public game;
    Monad public nft;

    address USER1 = makeAddr("user1");
    address USER2 = makeAddr("user2");
    address USER3 = makeAddr("user3");

    function setUp() public {
        nft = new Monad();
        game = new RPSgame(address(nft));
        vm.deal(USER1, 1 ether);
        vm.deal(USER2, 1 ether);
        vm.deal(USER3, 1 ether);
    }

    modifier twoUsersMinted() {
        vm.startPrank(USER1);
        nft.safeMint();
        nft.setApprovalForAll(address(game), true); // Разрешение для USER1
        vm.stopPrank();

        vm.startPrank(USER2);
        nft.safeMint();
        nft.setApprovalForAll(address(game), true); // Разрешение для USER2
        vm.stopPrank();
        _;
    }

    function testRevertsIfTokenDontExist() public {
        vm.startPrank(USER1);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));
        game.startGame(1, RPSgame.Choice.ROCK);
    }

    function testStartGame() public twoUsersMinted {
        vm.startPrank(USER1);
        game.startGame(0, RPSgame.Choice.ROCK);
        vm.stopPrank();

        (RPSgame.GameState state,,, address player1,,,,,,,) = game.s_games(1);
        assertEq(uint256(state), uint256(RPSgame.GameState.OPEN));
        assertEq(player1, USER1);
    }

    function testRevertsIfChoiceIsNone() public twoUsersMinted {
        vm.startPrank(USER1);
        vm.expectRevert(RPSgame.CantBeNone.selector);
        game.startGame(0, RPSgame.Choice.NONE);
        vm.stopPrank();
    }

    function testJoinGame() public twoUsersMinted {
        vm.startPrank(USER1);
        game.startGame(0, RPSgame.Choice.ROCK);
        vm.stopPrank();

        vm.startPrank(USER2);
        game.joinGame(1, 1, RPSgame.Choice.SCISSORS);
        vm.stopPrank();

        (,,,, address player2,,,,,,) = game.s_games(1);
        assertEq(player2, USER2);
    }

    function testRevertsIfGameDoesNotExist() public twoUsersMinted {
        vm.startPrank(USER1);
        game.startGame(0, RPSgame.Choice.ROCK);
        vm.stopPrank();

        vm.startPrank(USER2);
        vm.expectRevert(RPSgame.GameIsNotOpen.selector);
        game.joinGame(99, 1, RPSgame.Choice.SCISSORS);
        vm.stopPrank();
    }

    function testRevertsIfGameIsFull() public twoUsersMinted {
        vm.startPrank(USER1);
        game.startGame(0, RPSgame.Choice.ROCK);
        vm.stopPrank();

        vm.startPrank(USER2);
        game.joinGame(1, 1, RPSgame.Choice.SCISSORS);
        vm.stopPrank();

        vm.startPrank(USER3);
        nft.safeMint();
        nft.setApprovalForAll(address(game), true); // Разрешение для USER3
        vm.expectRevert(RPSgame.GameIsFull.selector);
        game.joinGame(1, 2, RPSgame.Choice.PAPER);
        vm.stopPrank();
    }

    function testRevertsIfNotApprovedForNFT1() public 
    {
        vm.startPrank(USER1);
        nft.safeMint();
        vm.stopPrank();

        vm.startPrank(USER2);
        nft.safeMint();
        nft.setApprovalForAll(address(game), true); // Разрешение для USER2
        vm.stopPrank();

        vm.startPrank(USER1);
        game.startGame(0, RPSgame.Choice.ROCK);
        vm.stopPrank();

        vm.startPrank(USER2);
        vm.expectRevert(RPSgame.NotApprovedForNFT1.selector);
        game.joinGame(1, 1, RPSgame.Choice.SCISSORS);
        vm.stopPrank();
    }

    function testRevertsIfNotApprovedForNFT2() public {
        vm.startPrank(USER1);
        nft.safeMint();
        nft.setApprovalForAll(address(game), true); // Разрешение для USER2
        vm.stopPrank();

        vm.startPrank(USER2);
        nft.safeMint();
        vm.stopPrank();

        vm.startPrank(USER1);
        game.startGame(0, RPSgame.Choice.ROCK);
        vm.stopPrank();

        vm.startPrank(USER2);
        vm.expectRevert(RPSgame.NotApprovedForNFT2.selector);
        game.joinGame(1, 1, RPSgame.Choice.SCISSORS);
        vm.stopPrank();
    }

    function testRevertsIfGameIsNotOpen() public twoUsersMinted {
        vm.startPrank(USER1);
        game.startGame(0, RPSgame.Choice.ROCK);
        vm.stopPrank();

        vm.startPrank(USER2);
        game.joinGame(1, 1, RPSgame.Choice.SCISSORS);
        vm.stopPrank();

        vm.startPrank(USER3);
        nft.safeMint();
        nft.setApprovalForAll(address(game), true); // Разрешение для USER3
        vm.expectRevert(RPSgame.GameIsFull.selector);
        game.joinGame(1, 2, RPSgame.Choice.PAPER);
        vm.stopPrank();
    }

      function testWinnerGetsNFT() public twoUsersMinted {
        // USER1 создает игру и выбирает "Камень"
        vm.startPrank(USER1);
        game.startGame(0, RPSgame.Choice.ROCK);
        vm.stopPrank();

        // USER2 присоединяется к игре и выбирает "Ножницы" (проигрыш)
        vm.startPrank(USER2);
        game.joinGame(1, 1, RPSgame.Choice.SCISSORS);
        vm.stopPrank();

        // Проверяем, что USER1 получил NFT USER2
        assertEq(nft.ownerOf(1), USER1); // NFT с tokenId = 1 теперь принадлежит USER1
        assertEq(nft.ownerOf(0), USER1); // NFT с tokenId = 0 остается у USER1
    }

}