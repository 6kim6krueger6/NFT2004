//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {NFTmonad} from "../src/NFTmonad.sol";

contract NFTmonadDeploy is Script {
    NFTmonad public nftmonad;

    address public constant MONAD_PROVIDER = 0x36825bf3Fbdf5a29E2d5148bfe7Dcf7B5639e320;

    function run() public {
        vm.startBroadcast();
        console.log("Deploying NFTmonad contract...");
        nftmonad = new NFTmonad(MONAD_PROVIDER);
        console.log("NFTmonad contract deployed at:", address(nftmonad));
        vm.stopBroadcast();
    }

}