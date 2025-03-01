//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
// import {NFTmonad} from "../src/NFTmonad.sol";
import {Monad} from "../src/Monad.sol";
import {RPSgame} from "../src/MonGame.sol";

contract NFTmonadDeploy is Script {
    // NFTmonad public nftmonad;
    Monad public monad;
    RPSgame public game;

    address public constant MONAD_PROVIDER = 0x36825bf3Fbdf5a29E2d5148bfe7Dcf7B5639e320;

    function run() public {
        vm.startBroadcast();
        console.log("Deploying NFTmonad contract...");
        // nftmonad = new NFTmonad(MONAD_PROVIDER);
        // monad = new Monad();
        game = new RPSgame(address(0x1e25FA098261C2C317E8Da868C8659daF1f3E1D6));

        // console.log("NFTmonad contract deployed at:", address(monad));
        console.log("RPSgame contract deployed at:", address(game));

        vm.stopBroadcast();
    }
}
