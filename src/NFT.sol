// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// public
// internal
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ERC2981} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";

import {VRFConsumerBaseV2Plus} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";


contract NFT is ERC721, ERC2981, VRFConsumerBaseV2Plus{
    error addressNotFound();
    error notEnoughFunds();
    error alreadyMinted();
    error uriNotFound();
    error failedWithdrawal();
    error TokenUriNotFound();

    uint256 private s_tokenCounter;

    uint256 private MINT_PRICE = 0.01 ether;
    bytes32 private constant MERKLE_ROOT = 0x10c2354320c3fa1945a8c52afcf0f38ef048959a4fab28f8c62191f0a1d1f065;
    uint96 public constant ROYALTY_PERCENTAGE = 500; // 5% (500 / 10000)
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1; //количество чисел в запросе

    uint256 private constant SUB_ID = 91382940516534283876546671246867629157790074374930250331029408967079844552570;
    bytes32 private constant KEY_HASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 private constant GAS_LIMIT = 100000;

    mapping (uint256 tokenId => string tokenUri) s_tokenToUri;
    mapping (address account => bool) s_hasMinted;

    // bytes32[] private  URI = ["ipfs://QmcTDhcEFkgqVVvhR8r7HCQrekQosvaf3CeKGs9v2PkDgD", "ipfs://QmYkw7Ee9zQnRTQqgj1WT4Q3XzPnPsqmUQbzckTHuKv578", "ipfs://QmcpPL1t3BjiFc7DmDF4WVMTmVYXEfyuhQR1bTwZqM5k7p", "ipfs://QmW7uTp8fB3pK5W6en1wiDrYrBeud9Xn6eHtGo4WnnSVc3", "ipfs://QmSQsjHhBW55JHhpKaf2AaV5nnxe6kuPy3JnfArVRXAdKT", "ipfs://QmRd1pACc4W2x9Do7vuRyHDb4gkjwmNCR8vwiZBS19itVY", "ipfs://QmVakoFq3vE6v7apjmFC5bHo3SbWrhGgKin7WJRH8cp7hy", "ipfs://QmYdxYdXqM4gF6bNQJXTiFEhAbGLebFDSuefiXu4vf5ice", "ipfs://QmRk1Pcs6iu9jhkoYoM6dT1H2t5iEHnnKL7R6F5vc16jtP", "ipfs://QmQqV67AjhcdGAkNDMA6tm7LrkRaRr6z3jBTsK8acEjZRR"];

    event CreatedNFT(uint256 indexed tokenId);
    event RequestFulfilled(uint256 indexed requestId, uint256[] randomWords);

    constructor()  ERC721("Monad Blasters", "MB") VRFConsumerBaseV2Plus(0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B)  {
        s_tokenCounter = 0;
        _setDefaultRoyalty(msg.sender, ROYALTY_PERCENTAGE);
    }


    function safeMint(bytes32[] calldata proof) public payable {
        if(s_hasMinted[msg.sender]) {
            revert alreadyMinted();
        }
        if(!verify(proof)) {
            revert addressNotFound();
        }
        if(msg.value != MINT_PRICE) {
            revert notEnoughFunds();
        }
        string memory tokenUri;
        uint256 _randomNumber = requestRandomWords();
        _randomNumber %= 1000;
        
        s_tokenToUri[s_tokenCounter] = tokenUri;
        _safeMint(msg.sender, s_tokenCounter);
        s_hasMinted[msg.sender] = true;
        
        s_tokenCounter++;
        emit CreatedNFT(s_tokenCounter);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (ownerOf(tokenId) == address(0)) {
            revert uriNotFound();
        }
        return s_tokenToUri[tokenId];
    }

    function verify(bytes32[] calldata _proof) internal view returns (bool) {
        return
            MerkleProof.verify(
                _proof,
                MERKLE_ROOT,
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

    function withdraw() external onlyOwner {
        if(address(this).balance == 0) {
            revert notEnoughFunds();
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
                subId: SUB_ID,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
                )
            })
        );
        return requestId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override  {
        requestId = randomWords[0];
        emit RequestFulfilled(requestId, randomWords);
    }

}
