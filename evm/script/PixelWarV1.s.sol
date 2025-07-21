// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PixelWar} from "../src/PixelWar.sol";

contract CounterScript is Script {
    PixelWar public pixelWar;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        pixelWar = new PixelWar(100); // 10%

        vm.stopBroadcast();
    }
}
