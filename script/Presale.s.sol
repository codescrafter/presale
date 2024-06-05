// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Presale} from "../src/Presale.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract PresaleScript is Script {
    function setUp() public {}

    function run() external returns (Presale) {
        vm.startBroadcast();

        // Deploy the Presale contract
        Presale presale = new Presale(
            IERC20(0xce488ed2d9854AAc72473b107D9FA5116Aa7e131), // token
            100, // price
            block.timestamp + 60, // start time
            block.timestamp + 86400 // end time
        );

        vm.stopBroadcast();
        return presale;
    }
}
