//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {VRFConsumerBaseV2Plus} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract NFTgame is VRFConsumerBaseV2Plus {
    error NotOwner();
    error GameIsNotOpen();
    error GameIsFull();
    error NotApprovedForNFT1();
    error NotApprovedForNFT2();

    enum GameState {
        OPEN,
        IN_PROGRESS
    }

    //state of the gamers
    struct GamerStatus {
        uint256 token_ID;
        uint256 randomNumber;
        address player;
        bool isWinner;
        bool fulfilled;
    }

    //state of the game
    struct Game {
        GameState gameState;
        uint256 tokenId1;
        uint256 tokenId2;
        address player1;
        address player2;
        uint256 randomNumber1;
        uint256 randomNumber2;
        bool fulfilled;
        bool isWinner1;
        bool isWinner2;
        bool isDraw;
    }

    struct RequestInfo {
        uint256 gameId;
        bool isPlayer1;
    }

    address public vrfCoordinator;

    uint256 public s_subId;
    address public s_nftContract;
    uint256 public s_gameId;
    GameState public s_gameState;

    bytes32 private constant KEY_HASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    // bytes32 private constant ARBI_KEY_HASH = 0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be;

    uint32 private constant GAS_LIMIT = 2500000;
    uint32 private constant NUM_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    mapping(uint256 gameId => GamerStatus) public s_gamerStatuses;
    mapping(uint256 gameId => Game) s_games;
    mapping(uint256 requestId => RequestInfo) public s_requestInfo;
    mapping(uint256 gameId => uint256[]) public s_gameRequests;

    event GameID(uint256 gameId);
    event GameResult(address player, uint256 gameID, bool isWinner);
    event GameStarted(uint256 gameId, address player1, uint256 tokenId1);
    event PlayerJoined(uint256 gameId, address player2, uint256 tokenId2);
    event RandomNumberRequested(uint256 requestId, uint256 gameId, bool isPlayer1);
    event RandomNumberFulfilled(uint256 requestId, uint256 gameId, uint256 randomNumber);
    event GameTie(uint256 gameId);

    constructor(address _nftContract, address _vrfCoordinator, uint256 _subId) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        s_nftContract = _nftContract;
        vrfCoordinator = _vrfCoordinator;
        s_subId = _subId;
        s_gameId = 0;
    }

    function startTheGame(uint256 tokenId) external {
        // putting your NFT's ID
        if (IERC721(s_nftContract).ownerOf(tokenId) != msg.sender) {
            revert IERC721Errors.ERC721NonexistentToken(tokenId); // revert if not owner
        }
        if (s_gameState != GameState.OPEN) {
            revert GameIsNotOpen();
        }
        s_gameState = GameState.IN_PROGRESS;
        s_gameId++; // id of your game
        s_games[s_gameId] = Game({ //saving information about the game
            gameState: GameState.IN_PROGRESS,
            tokenId1: tokenId,
            tokenId2: 0,
            player1: msg.sender,
            player2: address(0),
            randomNumber1: 0,
            randomNumber2: 0,
            fulfilled: false,
            isWinner1: false,
            isWinner2: false,
            isDraw: false
        });

        emit GameStarted(s_gameId, msg.sender, tokenId);
    }

    function joinTheGame(uint256 gameId, uint256 tokenId) external {
        //joining an existing game
        if (IERC721(s_nftContract).ownerOf(tokenId) != msg.sender) {
            revert IERC721Errors.ERC721NonexistentToken(tokenId); // revert if not owner
        }

        if (s_gameState != GameState.IN_PROGRESS) {
            revert GameIsNotOpen();
        }

        Game storage game = s_games[gameId]; //creating game object, changing it on storage memory
        if (game.tokenId2 != 0) {
            revert GameIsFull();
        }
        game.tokenId2 = tokenId;
        game.player2 = msg.sender;

        emit PlayerJoined(gameId, msg.sender, tokenId);
        requestRandomWords(gameId);
    }

    function requestRandomWords(uint256 gameId) internal {
        //creating 2 requests for 2 random numbers
        uint256 requestId1 = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: KEY_HASH,
                subId: s_subId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );

        uint256 requestId2 = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: KEY_HASH,
                subId: s_subId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );

        // Сохраняем последний requestId
        s_gameRequests[gameId].push(requestId1);
        s_gameRequests[gameId].push(requestId2);

        s_requestInfo[requestId1] = RequestInfo({gameId: gameId, isPlayer1: true});
        s_requestInfo[requestId2] = RequestInfo({gameId: gameId, isPlayer1: false});

        s_gamerStatuses[requestId1] = GamerStatus({
            token_ID: s_games[gameId].tokenId1,
            randomNumber: 0,
            player: s_games[gameId].player1,
            isWinner: false,
            fulfilled: false
        });

        s_gamerStatuses[requestId2] = GamerStatus({
            token_ID: s_games[gameId].tokenId2,
            randomNumber: 0,
            player: s_games[gameId].player2,
            isWinner: false,
            fulfilled: false
        });

        emit RandomNumberRequested(requestId1, gameId, true);
        emit RandomNumberRequested(requestId2, gameId, false);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        GamerStatus storage gamerStatus = s_gamerStatuses[requestId];
        gamerStatus.randomNumber = randomWords[0];
        gamerStatus.fulfilled = true;

        RequestInfo memory requestInfo = s_requestInfo[requestId];
        Game storage game = s_games[requestInfo.gameId];

        if (requestInfo.isPlayer1) {
            game.randomNumber1 = randomWords[0];
        } else {
            game.randomNumber2 = randomWords[0];
        }

        emit RandomNumberFulfilled(requestId, requestInfo.gameId, randomWords[0]);

        if (game.randomNumber1 != 0 && game.randomNumber2 != 0) {
            determineWinner(requestInfo.gameId);
        }
        s_gameState = GameState.OPEN;
    }

    function determineWinner(uint256 gameId) internal {
        Game storage game = s_games[gameId];
        if (
            !IERC721(s_nftContract).isApprovedForAll(game.player1, address(this))
                || IERC721(s_nftContract).getApproved(game.tokenId1) != address(this)
        ) {
            revert NotApprovedForNFT1();
        }

        if (
            !IERC721(s_nftContract).isApprovedForAll(game.player2, address(this))
                || IERC721(s_nftContract).getApproved(game.tokenId2) != address(this)
        ) {
            revert NotApprovedForNFT2();
        }

        if (game.randomNumber1 > game.randomNumber2) {
            game.isWinner1 = true;
            IERC721(s_nftContract).safeTransferFrom(game.player2, game.player1, game.tokenId2);
            emit GameResult(game.player1, gameId, true);
        } else if (game.randomNumber1 < game.randomNumber2) {
            game.isWinner2 = true;
            IERC721(s_nftContract).safeTransferFrom(game.player1, game.player2, game.tokenId1);
            emit GameResult(game.player2, gameId, true);
        } else {
            // Ничья
            game.isDraw = true;
            emit GameTie(gameId);
        }

        game.fulfilled = true;
        emit GameResult(game.isWinner1 ? game.player1 : game.player2, gameId, true);
    }

    function getSubId() public view returns (uint256) {
        return s_subId;
    }

    function getVrfCoordinator() public view returns (address) {
        return vrfCoordinator;
    }

    function getGameId() public view returns (uint256) {
        return s_gameId;
    }

    function getGameRequests(uint256 gameId) external view returns (uint256[] memory) {
        return s_gameRequests[gameId];
    }

    function getGame(uint256 gameId)
        public
        view
        returns (
            GameState gameState,
            uint256 tokenId1,
            uint256 tokenId2,
            address player1,
            address player2,
            uint256 randomNumber1,
            uint256 randomNumber2,
            bool fulfilled,
            bool isWinner1,
            bool isWinner2,
            bool isDraw
        )
    {
        Game storage game = s_games[gameId];
        return (
            game.gameState,
            game.tokenId1,
            game.tokenId2,
            game.player1,
            game.player2,
            game.randomNumber1,
            game.randomNumber2,
            game.fulfilled,
            game.isWinner1,
            game.isWinner2,
            game.isDraw
        );
    }
}
