// SPDX-License-Identifier: SEE LICENSE IN LICENSE
// pragma solidity ^0.8.19;
pragma solidity >=0.6.2 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {YeahDollar} from "../src/YeahDollar.sol";

contract DeployYeahDollar is Script {
    function run() external returns (YeahDollar) {
        vm.startBroadcast();
        YeahDollar yeahDollar = new YeahDollar();
        vm.stopBroadcast();
        return yeahDollar;
    }
}
