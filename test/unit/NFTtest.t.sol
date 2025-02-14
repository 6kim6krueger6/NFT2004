//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {NFT} from "../../src/NFT.sol";
import {NFTdeploy} from "../../script/NFTdeploy.s.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract NFTtest is Test {
    NFT public nft;
    address public USER = makeAddr("user");
    uint256 public constant MINT_PRICE = 0.01 ether;
    uint256 public constant USER_BALANCE = 0.1 ether; // 5% (500 / 10000)

    function setUp() public {
        vm.deal(USER, USER_BALANCE);
    }

    function testUserCanMint() public {
        nft = new NFT();
        vm.prank(USER);
        nft.safeMint{value: MINT_PRICE}();
        uint256 final_balance = USER_BALANCE - MINT_PRICE;
        assertEq(nft.balanceOf(USER), final_balance);
    }

}