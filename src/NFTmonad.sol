// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC2981} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";

import {IEntropyConsumer} from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import {IEntropy} from "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";

contract NFTmonad is ERC721, ERC2981, IEntropyConsumer {
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
        bytes32 randomNumber;
        address minter;
    }

    uint256 private s_tokenCounter;
    MintState public s_mintState;

    uint256 public immutable i_mintDeadline;
    uint256 private constant MINT_PRICE = 0.01 ether;
    uint256 public constant MINT_TIME = 30 days;
    uint96 public constant ROYALTY_PERCENTAGE = 500;

    // MERKLE ROOTS
    bytes32 private constant MERKLE_ROOT = 0x3598678e8e03d37d8142773eee52c9e6b879fb9a8864011cb31eda78c38b0153;

    IEntropy public entropy;

    mapping(uint256 tokenId => string tokenUri) s_tokenToUri;
    mapping(address account => bool) s_hasMinted;
    mapping(uint256 => RequestStatus) public s_requests;
    mapping(uint256 => bool) public s_UriExists;

    // EVENTS
    event CreatedNFT(uint256 indexed tokenId, address indexed minter, string tokenUri);
    event RequestFulfilled(uint256 indexed requestId, bytes32 randomNumber);
    event MintError(address indexed user, string reason);
    event WithdrawalError(address indexed user, string reason);
    event MintSuccessful(address indexed user, uint256 tokenId);
    event RandomRequestCreated(uint256 indexed requestId, address indexed user);

    constructor(address _entropy) ERC721("DinoDuels", "DD") {
        s_tokenCounter = 0;
        _setDefaultRoyalty(msg.sender, ROYALTY_PERCENTAGE);
        i_mintDeadline = block.timestamp + MINT_TIME;
        s_mintState = MintState.OPEN;
        entropy = IEntropy(_entropy);
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

        bytes32 userRandomNumber = keccak256(abi.encodePacked(msg.sender, block.timestamp));
        uint256 requestId = uint256(userRandomNumber);
        requestRandomNumber(userRandomNumber);
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

    function setRoyalty(address receiver, uint96 feeNumerator) external {
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

    function requestRandomNumber(bytes32 userRandomNumber) internal {
        // Get the default provider and the fee for the request
        address entropyProvider = entropy.getDefaultProvider();
        uint256 fee = entropy.getFee(entropyProvider);

        // Request the random number with the callback
        uint64 sequenceNumber = entropy.requestWithCallback{value: fee}(entropyProvider, userRandomNumber);

        // Store the sequence number to identify the callback request
        uint256 requestId = uint256(sequenceNumber);
        s_requests[requestId] = RequestStatus({randomNumber: 0, exists: true, fulfilled: false, minter: msg.sender});
    }

    function entropyCallback(
        uint64 sequenceNumber,
        address, /* provider */ 
        bytes32 randomNumber
    ) internal override {
        if (!s_requests[sequenceNumber].exists) {
            emit MintError(msg.sender, "Request ID not found.");
            revert requestNotFound();
        }

        RequestStatus storage request = s_requests[sequenceNumber];
        request.fulfilled = true;
        request.randomNumber = randomNumber;

        address minter = request.minter;
        uint256 uriId = uint256(randomNumber) % 200;

        while (s_UriExists[uriId]) {
            uriId = uint256(keccak256(abi.encode(randomNumber, uriId, block.timestamp))) % 200;
        }

        string memory tokenUri = string(abi.encodePacked(_baseURI(), Strings.toString(uriId), ".json"));

        s_UriExists[uriId] = true;
        s_tokenToUri[s_tokenCounter] = tokenUri;
        _safeMint(minter, s_tokenCounter);
        emit MintSuccessful(minter, s_tokenCounter);
        emit CreatedNFT(s_tokenCounter, minter, tokenUri);
        s_tokenCounter++;

        emit RequestFulfilled(sequenceNumber, randomNumber);
    }

    function getMintState() public view returns (MintState) {
        return s_mintState;
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }

    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }
}
