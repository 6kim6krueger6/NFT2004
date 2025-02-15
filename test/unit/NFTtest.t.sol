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
    address public constant vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;

   function setUp() public {
    vm.deal(USER, USER_BALANCE);

    // Разворачиваем Mock VRFCoordinator
    VRFCoordinatorV2_5Mock mockCoordinator = new VRFCoordinatorV2_5Mock(100000000000000000, 1, 2000000000000000);
    console.log("VRFCoordinatorV2_5Mock deployed at address:", address(mockCoordinator));

    uint256 subId = mockCoordinator.createSubscription();
    nft = new NFT(address(mockCoordinator)); 
    mockCoordinator.fundSubscription(subId, 1 ether);
    mockCoordinator.addConsumer(subId, address(nft));
}

    function testUserCanMint() public {
        vm.startPrank(USER);

        nft.safeMint{value: MINT_PRICE}();
        vm.stopPrank();
        
        uint256 final_balance = USER_BALANCE - MINT_PRICE;
        uint256 actual_balance = address(USER).balance;
        assertEq(actual_balance, final_balance);
    }


}