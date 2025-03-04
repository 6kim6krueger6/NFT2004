// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ChristCross {
    enum GameState {
        OPEN,
        CALCULATING,
        CLOSED
    }

    struct Choices {
        uint256 square1x1;
        uint256 square1x2;
        uint256 square1x3;
        uint256 square2x1;
        uint256 square2x2;
        uint256 square2x3;
        uint256 square3x1;
        uint256 square3x2;
        uint256 square3x3;
    }

    struct Game {
        GameState gameState;
        uint256 tokenId1;
        uint256 tokenId2;
        address player1;
        address player2;
        Choices choices1;
        Choices choices2;
        bool fullfilled;
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

    function startGame(uint256 tokenId) external {
        require(s_gameState == GameState.OPEN, "Game is not open");
        s_gameState = GameState.OPEN;
        s_gameId++;
        s_games[s_gameId] = Game({
            gameState: GameState.OPEN,
            tokenId1: tokenId,
            tokenId2: 0,
            player1: msg.sender,
            player2: address(0),
            choices1: Choices({ 
                square1x1: 0,
                square1x2: 0,
                square1x3: 0,
                square2x1: 0,
                square2x2: 0,
                square2x3: 0,
                square3x1: 0,
                square3x2: 0,
                square3x3: 0
            }),
            choices2: Choices({ 
                square1x1: 0,
                square1x2: 0,
                square1x3: 0,
                square2x1: 0,
                square2x2: 0,
                square2x3: 0,
                square3x1: 0,
                square3x2: 0,
                square3x3: 0
            }),
            fullfilled: false,
            isWinner1: false,
            isWinner2: false,
            isDraw: false
        });
    }

    function joinGame(uint256 gameId, uint256 tokenId) external {
        require(s_gameState == GameState.OPEN, "Game is not open");
        Game storage game = s_games[gameId];
        require(game.tokenId2 == 0, "Game is full");
        require(msg.sender != game.player1, "You are already in this game");
        game.tokenId2 = tokenId;
        game.player2 = msg.sender;
        game.gameState = GameState.CALCULATING;
        s_gameState = GameState.CALCULATING;
    }

    function makeMove() external{
        
    }
}