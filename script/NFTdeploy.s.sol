// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {NFT} from "../src/NFT.sol";

contract NFTdeploy is Script {
    NFT public nft;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        nft = new NFT();
        vm.stopBroadcast();
    }
}
