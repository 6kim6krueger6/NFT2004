// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

    enum MintState {
        OPEN,
        CLOSED
    }

    struct RequestStatus {
        bool fulfilled; 
        bool exists; 
        uint256[] randomWords;
        address minter;
    }

    uint256 public s_subId;
    uint256 private s_tokenCounter;
    uint256 private s_mintDeadline;
    uint256 private s_lastRequestId; // ID последнего отправленного реквеста
    address private vrfCoordinator;
    MintState public s_mintState;

    uint256 private constant MINT_PRICE = 0.01 ether;
    bytes32 private constant MERKLE_ROOT = 0x10c2354320c3fa1945a8c52afcf0f38ef048959a4fab28f8c62191f0a1d1f065;
    bytes32 private constant ANVIL_ROOT = 0xd4453790033a2bd762f526409b7f358023773723d9e9bc42487e4996869162b6;

    uint96 public constant ROYALTY_PERCENTAGE = 500; // 5% (500 / 10000)
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1; // количество чисел в запросе

    uint256 private constant SUB_ID = 100989143403752757787427797522328206917911361128080942187540010049546367787741;
    bytes32 private constant KEY_HASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 private constant GAS_LIMIT = 500000000;

    uint256 public constant MINT_TIME = 30 days;

    mapping(uint256 tokenId => string tokenUri) s_tokenToUri;
    mapping(address account => bool) s_hasMinted;
    mapping(uint256 => RequestStatus) public s_requests;
    mapping(uint256 => bool) public s_UriExists;

    event CreatedNFT(uint256 indexed tokenId);
    event RequestFulfilled(uint256 indexed requestId, uint256[] randomWords);

    constructor(address _vrfCoordinator, uint256 _subId) ERC721("Dinads BOS", "DB") VRFConsumerBaseV2Plus(_vrfCoordinator) {
        s_tokenCounter = 0;
        _setDefaultRoyalty(msg.sender, ROYALTY_PERCENTAGE);
        s_mintDeadline = block.timestamp + MINT_TIME;
        s_mintState = MintState.OPEN;
        vrfCoordinator = _vrfCoordinator;
        s_subId = _subId;
    }

    function safeMint() public payable {
        if (block.timestamp > s_mintDeadline) {
            s_mintState = MintState.CLOSED;
            revert mintIsOver();
        }

        if (s_hasMinted[msg.sender]) {
            revert alreadyMinted();
        }

        if (msg.value < MINT_PRICE) {
            revert notEnoughFunds();
        }

        uint256 requestId = requestRandomWords();

        s_requests[requestId].minter = msg.sender;

        s_hasMinted[msg.sender] = true;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://ipfs.io/ipfs/QmNZ5FcyWbjhHAWKf494M45f9nUedSmxzwMkah71W1r2U9/";
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (ownerOf(tokenId) == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        return s_tokenToUri[tokenId];
    }

    function verify(bytes32[] calldata _proof) internal view returns (bool) {
        return
            MerkleProof.verify(
                _proof,
                MERKLE_ROOT,
                // ANVIL_ROOT,
                keccak256(abi.encodePacked(msg.sender))
            );
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function setRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function withdraw(bytes32[] calldata proof) external {
        if (address(this).balance == 0) {
            revert notEnoughFunds();
        }
        if (!verify(proof)) {
            revert addressNotFound();
        }

        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        if (!success) {
            revert failedWithdrawal();
        }
    }

    function requestRandomWords() internal returns (uint256 requestId) {
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: KEY_HASH,
                subId: s_subId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false,
            minter: address(0)
        });
        s_lastRequestId = requestId;
        return requestId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        if (!s_requests[requestId].exists) {
            revert requestNotFound();
        }

        RequestStatus storage request = s_requests[requestId];
        request.fulfilled = true;
        request.randomWords = randomWords;

        address minter = request.minter;
        uint256 uriId = randomWords[0] % 1000;

        // Если uriId уже существует, пытаемся найти свободный
        while (s_UriExists[uriId]) {
            uriId = uint256(keccak256(abi.encode(randomWords[0], uriId, block.timestamp))) % 1000;
        }

        string memory tokenUri = string(abi.encodePacked(_baseURI(), Strings.toString(uriId), ".json"));

        s_UriExists[uriId] = true;
        s_tokenToUri[s_tokenCounter] = tokenUri;
        _safeMint(minter, s_tokenCounter);
        s_tokenCounter++;

        emit RequestFulfilled(requestId, randomWords);
        emit CreatedNFT(s_tokenCounter - 1);
    }

    function getLatestRequestId() public view returns (uint256) {
        return s_lastRequestId;
    }

    function getMintState() public view returns (MintState) {
        return s_mintState;
    }
}