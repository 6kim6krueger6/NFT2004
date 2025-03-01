// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";

contract Monad is ERC721, ERC2981 {
    error addressNotFound();
    error notEnoughFunds();
    error alreadyMinted();
    error failedWithdrawal();
    error TokenUriNotFound();
    error mintIsOver();

    // MINT INFORMATION
    enum MintState {
        OPEN,
        CLOSED
    }

    uint256 private s_tokenCounter;
    MintState public s_mintState;

    uint256 public immutable i_mintDeadline;
    uint256 public constant MINT_TIME = 30 days;
    uint96 public constant ROYALTY_PERCENTAGE = 500;

    // MERKLE ROOTS
    bytes32 private constant MERKLE_ROOT = 0x3598678e8e03d37d8142773eee52c9e6b879fb9a8864011cb31eda78c38b0153;

    mapping(uint256 tokenId => string tokenUri) s_tokenToUri;
    mapping(address account => bool) s_hasMinted;
    mapping(uint256 => bool) public s_UriExists;

    // EVENTS
    event CreatedNFT(uint256 indexed tokenId, address indexed minter, string tokenUri);
    event MintError(address indexed user, string reason);
    event WithdrawalError(address indexed user, string reason);
    event MintSuccessful(address indexed user, uint256 tokenId);

    constructor() ERC721("DinoDuels", "DD") {
        s_tokenCounter = 0;
        _setDefaultRoyalty(msg.sender, ROYALTY_PERCENTAGE);
        i_mintDeadline = block.timestamp + MINT_TIME;
        s_mintState = MintState.OPEN;
    }

    // MINT FUNCTION
    function safeMint() public {
        if (block.timestamp > i_mintDeadline) {
            s_mintState = MintState.CLOSED;
            emit MintError(msg.sender, "Minting period is over.");
            revert mintIsOver();
        }

        if (s_hasMinted[msg.sender]) {
            emit MintError(msg.sender, "Address has already minted.");
            revert alreadyMinted();
        }

        uint256 tokenId = s_tokenCounter;
        string memory tokenUri = string(abi.encodePacked(_baseURI(), Strings.toString(tokenId), ".json"));

        s_tokenToUri[tokenId] = tokenUri;
        s_hasMinted[msg.sender] = true;
        _safeMint(msg.sender, tokenId);
        emit MintSuccessful(msg.sender, tokenId);
        emit CreatedNFT(tokenId, msg.sender, tokenUri);
        s_tokenCounter++;
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

    function getMintState() public view returns (MintState) {
        return s_mintState;
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }
}
