// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Generative NFT contract, with royalty and VRF
 * created by https://github.com/6kim6krueger6
 * visit https://github.com/6kim6krueger6/NFT2004 for more info
 * @title created specially for Monad EVM hackathon
 */
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC2981} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {VRFConsumerBaseV2Plus} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract NFT is ERC721, ERC2981, VRFConsumerBaseV2Plus {
    error addressNotFound();
    error notEnoughFunds();
    error alreadyMinted();
    error failedWithdrawal();
    error TokenUriNotFound();
    error mintIsOver();
    error requestNotFound();

    // MINT INFORMATION
    enum MintState {
        OPEN,
        CLOSED
    }

    // VRF INFORMATION
    struct RequestStatus {
        bool fulfilled;
        bool exists;
        uint256[] randomWords;
        address minter;
    }

    uint256 private s_subId;
    uint256 private s_tokenCounter;
    uint256 private s_lastRequestId;
    address private vrfCoordinator;

    MintState public s_mintState;

    uint256 public immutable i_mintDeadline;
    uint256 private constant MINT_PRICE = 0.01 ether;
    uint256 public constant MINT_TIME = 30 days;
    uint96 public constant ROYALTY_PERCENTAGE = 500;

    // MERKLE ROOTS
    bytes32 private constant MERKLE_ROOT = 0x3598678e8e03d37d8142773eee52c9e6b879fb9a8864011cb31eda78c38b0153;

    // CHAINLINK VARIABLES
    // bytes32 private constant KEY_HASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    bytes32 private constant ARBI_KEY_HASH = 0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be;

    uint32 private constant GAS_LIMIT = 2000000;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    mapping(uint256 tokenId => string tokenUri) s_tokenToUri;
    mapping(address account => bool) s_hasMinted;
    mapping(uint256 => RequestStatus) public s_requests;
    mapping(uint256 => bool) public s_UriExists;

    // EVENTS
    event CreatedNFT(uint256 indexed tokenId, address indexed minter, string tokenUri);
    event RequestFulfilled(uint256 indexed requestId, uint256[] randomWords);
    event MintError(address indexed user, string reason);
    event WithdrawalError(address indexed user, string reason);
    event MintSuccessful(address indexed user, uint256 tokenId);
    event RandomRequestCreated(uint256 indexed requestId, address indexed user);

    constructor(address _vrfCoordinator, uint256 _subId)
        ERC721("Dinads BOS", "DB")
        VRFConsumerBaseV2Plus(_vrfCoordinator)
    {
        s_tokenCounter = 0;
        _setDefaultRoyalty(msg.sender, ROYALTY_PERCENTAGE);
        i_mintDeadline = block.timestamp + MINT_TIME;
        s_mintState = MintState.OPEN;
        vrfCoordinator = _vrfCoordinator;
        s_subId = _subId;
    }

    // MINT FUNCTION
    function safeMint() public payable {
        if (block.timestamp > i_mintDeadline) {
            s_mintState = MintState.CLOSED;
            emit MintError(msg.sender, "Minting period is over.");
            revert mintIsOver();
        }

        if (s_hasMinted[msg.sender]) {
            emit MintError(msg.sender, "Address has already minted.");
            revert alreadyMinted();
        }

        if (msg.value < MINT_PRICE) {
            emit MintError(msg.sender, "Insufficient payment.");
            revert notEnoughFunds();
        }

        uint256 requestId = requestRandomWords();
        s_requests[requestId].minter = msg.sender;
        s_hasMinted[msg.sender] = true;

        emit RandomRequestCreated(requestId, msg.sender);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://ipfs.io/ipfs/QmcfGaqaCBK66xCZUyBCuVBy7Cjn4G5HYr2USYLhU29k3f/";
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (ownerOf(tokenId) == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        return s_tokenToUri[tokenId];
    }

    function verify(bytes32[] calldata _proof) internal view returns (bool) {
        return MerkleProof.verify(_proof, MERKLE_ROOT, keccak256(abi.encodePacked(msg.sender)));
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function withdraw(bytes32[] calldata proof) external {
        if (address(this).balance == 0) {
            emit WithdrawalError(msg.sender, "No funds to withdraw.");
            revert notEnoughFunds();
        }
        if (!verify(proof)) {
            emit WithdrawalError(msg.sender, "Address not authorized.");
            revert addressNotFound();
        }

        (bool success,) = msg.sender.call{value: address(this).balance}("");
        if (!success) {
            emit WithdrawalError(msg.sender, "Failed to withdraw funds.");
            revert failedWithdrawal();
        }
    }

    function requestRandomWords() internal returns (uint256 requestId) {
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: ARBI_KEY_HASH,
                subId: s_subId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        s_requests[requestId] =
            RequestStatus({randomWords: new uint256[](0), exists: true, fulfilled: false, minter: address(0)});
        s_lastRequestId = requestId;
        return requestId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        if (!s_requests[requestId].exists) {
            emit MintError(msg.sender, "Request ID not found.");
            revert requestNotFound();
        }

        RequestStatus storage request = s_requests[requestId];
        request.fulfilled = true;
        request.randomWords = randomWords;

        address minter = request.minter;
        uint256 uriId = randomWords[0] % 100;

        while (s_UriExists[uriId]) {
            uriId = uint256(keccak256(abi.encode(randomWords[0], uriId, block.timestamp))) % 100;
        }

        string memory tokenUri = string(abi.encodePacked(_baseURI(), Strings.toString(uriId), ".json"));

        s_UriExists[uriId] = true;
        s_tokenToUri[s_tokenCounter] = tokenUri;
        _safeMint(minter, s_tokenCounter);
        emit MintSuccessful(minter, s_tokenCounter);
        emit CreatedNFT(s_tokenCounter, minter, tokenUri);
        s_tokenCounter++;

        emit RequestFulfilled(requestId, randomWords);
    }

    function getLatestRequestId() public view returns (uint256) {
        return s_lastRequestId;
    }

    function getMintState() public view returns (MintState) {
        return s_mintState;
    }

    function getSubId() public view returns (uint256) {
        return s_subId;
    }

    function getVrfCoordinator() public view returns (address) {
        return address(vrfCoordinator);
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }
}
