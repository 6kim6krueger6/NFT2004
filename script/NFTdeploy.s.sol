// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {NFT} from "../src/NFT.sol";

contract NFTdeploy is Script {
    NFT public nft;
    uint256 public constant SUB_ID = 86906349064437370453981867026856126551436515075430136612035847446893057741160;    
    address public constant VRF_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    
    function run() public {
        vm.startBroadcast();
        nft = new NFT(VRF_COORDINATOR,SUB_ID);
        vm.stopBroadcast();
    }
}
