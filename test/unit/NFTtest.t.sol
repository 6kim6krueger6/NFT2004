// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {NFT} from "../../src/NFT.sol";
import {VRFCoordinatorV2_5Mock} from
    "chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract NFTTest is Test {
    NFT public nft;
    VRFCoordinatorV2_5Mock public vrfCoordinator;

    bytes32[] proof = [
        bytes32(0x00314e565e0574cb412563df634608d76f5c59d9f817e85966100ec1d48005c0),
        bytes32(0x7e0eefeb2d8740528b8f598997a219669f0842302d3c573e9bb7262be3387e63)
    ];

    address public user = address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720);
    address public owner = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    uint96 public baseFee = 0.1 ether;
    uint96 public gasPrice = 20 gwei;
    int256 public weiPerUnitLink = 0.0005 ether;
    uint256 public subId;

    function setUp() public {
        vrfCoordinator = new VRFCoordinatorV2_5Mock(baseFee, gasPrice, weiPerUnitLink);
        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, 1000 ether);
        nft = new NFT(address(vrfCoordinator), subId);
        vrfCoordinator.addConsumer(subId, address(nft));

        vm.deal(user, 1 ether);
    }

    function testSuccessfulMint() public {
        vm.startPrank(user);

        nft.safeMint{value: 0.01 ether}();

        uint256 requestId = nft.getLatestRequestId();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 1234533331133333311 % 1000;
        vrfCoordinator.fulfillRandomWords(requestId, address(nft));

        assertEq(nft.ownerOf(0), user);
        vm.stopPrank();
    }

    function testRevertIfUserAlreadyMinted() public {
        vm.startPrank(user);
        nft.safeMint{value: 0.01 ether}();
        uint256 requestId = nft.getLatestRequestId();
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        vrfCoordinator.fulfillRandomWords(requestId, address(nft));

        vm.expectRevert(NFT.alreadyMinted.selector);
        nft.safeMint{value: 0.01 ether}();
        vm.stopPrank();
    }

    function testRevertIfNotEnoughFunds() public {
        vm.expectRevert(NFT.notEnoughFunds.selector);
        nft.safeMint{value: 0.009 ether}();
        vm.stopPrank();
    }

    function testRevertIfMintIsOver() public {
        vm.startPrank(user);
        vm.warp(block.timestamp + 31 days);
        vm.expectRevert(NFT.mintIsOver.selector);
        nft.safeMint{value: 0.01 ether}();
        vm.stopPrank();
    }

    modifier userMinted() {
        vm.startPrank(user);
        nft.safeMint{value: 0.01 ether}();
        uint256 requestId = nft.getLatestRequestId();
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 1234533331133333311 % 1000;
        vrfCoordinator.fulfillRandomWords(requestId, address(nft));
        vm.stopPrank();
        _;
    }

    function testOnlyChosenCanWithdraw() public userMinted {
        vm.startPrank(owner);
        vm.expectRevert(NFT.addressNotFound.selector);
        nft.withdraw(proof);
        vm.stopPrank();
    }

    function testRevertIfUserWithdraws() public userMinted {
        vm.startPrank(user);
        vm.expectRevert(NFT.addressNotFound.selector);
        nft.withdraw(proof);
        vm.stopPrank();
    }

    function testCantWithdrawIfNoMoney() public {
        vm.startPrank(owner);
        vm.expectRevert(NFT.notEnoughFunds.selector);
        nft.withdraw(proof);
        vm.stopPrank();
    }

    function testUriRevertsIfIdDontExist() public userMinted {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 55));
        nft.tokenURI(55);
        vm.stopPrank();
    }

    function testFuzzSuccessfulMint(address _user, uint256 randomValue) public {
        vm.assume(_user != address(0)); // Исключаем нулевой адрес
        vm.assume(_user.code.length == 0); // Исключаем контракты (только EOAs)
        vm.assume(randomValue > 0 && randomValue <= 1000); // Убеждаемся, что число не ноль

        vm.deal(_user, 1 ether);
        vm.startPrank(user);

        nft.safeMint{value: 0.01 ether}();

        uint256 requestId = nft.getLatestRequestId();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 1234533331133333311 % 1000;
        vrfCoordinator.fulfillRandomWords(requestId, address(nft));

        assertEq(nft.ownerOf(0), user);
        vm.stopPrank();
    }
}
