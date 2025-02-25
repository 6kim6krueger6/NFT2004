// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {NFT} from "../src/NFT.sol";
import {NFTgame} from "../src/NFTgame.sol";

contract NFTdeploy is Script {
    NFT public nft;
    // NFTgame public nftgame;
    uint256 public constant SUB_ID = 86906349064437370453981867026856126551436515075430136612035847446893057741160;
    uint256 public constant ARBI_SUB_ID = 53908118885474722263942425361989802159991757705438179707859027354892638640928;

    address public constant VRF_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    address public constant ARBI_VRF_COORDINATOR = 0x5CE8D5A2BC84beb22a398CCA51996F7930313D61;

    address public constant NFT_ADDRESS = 0xb70d4333545BB648bDFA4B30DE9d13B12Ec3F6a8;
    // address public constant ARBI_NFT_ADDRESS;

    function run() public {
        vm.startBroadcast();
        console.log("Deploying NFT contract...");
        nft = new NFT(ARBI_VRF_COORDINATOR, ARBI_SUB_ID);
        // nftgame = new NFTgame(NFT_ADDRESS, VRF_COORDINATOR, SUB_ID);
        console.log("NFT contract deployed at:", address(nft));
        // console.log("NFTgame contract deployed at:", address(nftgame));
        vm.stopBroadcast();
    }
}
