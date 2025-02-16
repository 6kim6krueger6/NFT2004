//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {NFT} from "../../src/NFT.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {NFTdeploy} from "script/NFTdeploy.s.sol";

contract IntegrationTest is Test {
    NFTdeploy deployer;
    NFT public nft;

    function setUp() public {
        deployer = new NFTdeploy();
        deployer.run();
        nft = deployer.nft();
    }

    function testNFTDeployed() public view {
        assertTrue(address(nft) != address(0), "NFT contract not deployed");
    }

    function testVRFCoordinatorSetCorrectly() public view {
        address vrfCoordinator = nft.getVrfCoordinator();
        assertEq(vrfCoordinator, deployer.VRF_COORDINATOR(), "VRF_COORDINATOR not set correctly");
    }

    function testSubIdSetCorrectly() public view {
        uint256 subId = nft.getSubId();
        assertEq(subId, deployer.SUB_ID(), "SUB_ID not set correctly");
    }

    function testInitialState() public view {
        assertEq(nft.getTokenCounter(), 0, "Initial token counter should be 0");
        assertEq(uint256(nft.s_mintState()), uint256(NFT.MintState.OPEN), "Initial mint state should be OPEN");
    }
}