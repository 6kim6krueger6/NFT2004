// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract RPSgame {
    error GameIsNotOpen();
    error GameIsFull();
    error NotApprovedForNFT1();
    error NotApprovedForNFT2();
    error CantBeNone();
    error GameIsNotCalculating();

    enum GameState {
        OPEN,
        CALCULATING,
        CLOSED
    }

    enum Choice {
        ROCK,
        PAPER,
        SCISSORS,
        NONE
    }

    struct Game {
        GameState gameState;
        uint256 tokenId1;
        uint256 tokenId2;
        address player1;
        address player2;
        Choice player1choice;
        Choice player2choice;
        bool fulfilled;
        bool isWinner1;
        bool isWinner2;
        bool isDraw;
    }

    address public immutable s_nftContract;
    GameState public s_gameState;
    uint256 public s_gameId;

    mapping(uint256 gameId => Game) public s_games;

    constructor(address _nftContract) {
        s_nftContract = _nftContract;
        s_gameId = 0;
    }

    event GameCreated(uint256 gameId, address player1, uint256 tokenId1);
    event PlayerJoined(uint256 gameId, address player2, uint256 tokenId2);
    event GameResult(address player, uint256 gameID, bool isWinner);

    function startGame(uint256 tokenId, Choice _choice) external {
        if (IERC721(s_nftContract).ownerOf(tokenId) != msg.sender) {
            revert IERC721Errors.ERC721NonexistentToken(tokenId); // revert if not owner
        }
        if (s_gameState != GameState.OPEN) {
            revert GameIsNotOpen();
        }
        if (_choice == Choice.NONE) {
            revert CantBeNone();
        }
        s_gameState = GameState.OPEN;
        s_gameId++;
        s_games[s_gameId] = Game({
            gameState: GameState.OPEN,
            tokenId1: tokenId,
            tokenId2: 0,
            player1: msg.sender,
            player2: address(0),
            player1choice: _choice,
            player2choice: Choice.NONE,
            fulfilled: false,
            isWinner1: false,
            isWinner2: false,
            isDraw: false
        });

        emit GameCreated(s_gameId, msg.sender, tokenId);
    }

    function joinGame(uint256 gameId, uint256 tokenId, Choice _choice) external {
    if (IERC721(s_nftContract).ownerOf(tokenId) != msg.sender) {
        revert IERC721Errors.ERC721NonexistentToken(tokenId); // revert if not owner
    }
    if (s_gameState != GameState.OPEN) {
        revert GameIsNotOpen();
    }
    if (_choice == Choice.NONE) {
        revert CantBeNone();
    }

    Game storage game = s_games[gameId];
    if (game.player1 == address(0)) { // Проверка, что игра существует
        revert GameIsNotOpen();
    }
    if (game.tokenId2 != 0) {
        revert GameIsFull();
    }

    game.tokenId2 = tokenId;
    game.player2 = msg.sender;
    game.player2choice = _choice;
    emit PlayerJoined(gameId, msg.sender, tokenId);
    game.gameState = GameState.CALCULATING;
    s_gameState = GameState.CALCULATING;
    calculateWinner(gameId);
    game.fulfilled = true;
    s_gameState = GameState.OPEN;
}

    function calculateWinner(uint256 gameId) internal {
        Game storage game = s_games[gameId];

        if (
            !IERC721(s_nftContract).isApprovedForAll(game.player1, address(this))
                // || IERC721(s_nftContract).getApproved(game.tokenId1) != address(this)
        ) {
            revert NotApprovedForNFT1();
        }

        if (
            !IERC721(s_nftContract).isApprovedForAll(game.player2, address(this))
                // || IERC721(s_nftContract).getApproved(game.tokenId2) != address(this)
        ) {
            revert NotApprovedForNFT2();
        }

        if (game.gameState != GameState.CALCULATING) {
            revert GameIsNotCalculating();
        }

        if (game.player1choice == game.player2choice) {
            game.isDraw = true;
            emit GameResult(game.player1, gameId, game.isWinner1);
            emit GameResult(game.player2, gameId, game.isWinner2);
        } else if (
            (game.player1choice == Choice.ROCK && game.player2choice == Choice.SCISSORS)
                || (game.player1choice == Choice.PAPER && game.player2choice == Choice.ROCK)
                || (game.player1choice == Choice.SCISSORS && game.player2choice == Choice.PAPER)
        ) {
            game.isWinner1 = true;
            IERC721(s_nftContract).safeTransferFrom(game.player2, game.player1, game.tokenId2);
            emit GameResult(game.player1, gameId, game.isWinner1);
            emit GameResult(game.player2, gameId, game.isWinner2);
        } else {
            game.isWinner2 = true;
            IERC721(s_nftContract).safeTransferFrom(game.player1, game.player2, game.tokenId1);
            emit GameResult(game.player1, gameId, game.isWinner1);
            emit GameResult(game.player2, gameId, game.isWinner2);
        }
        game.gameState = GameState.CLOSED;
    }
}
