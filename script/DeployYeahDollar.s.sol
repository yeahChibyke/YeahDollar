// SPDX-License-Identifier: SEE LICENSE IN LICENSE
// pragma solidity ^0.8.19;
pragma solidity >=0.6.2 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {YeahDollar} from "../src/YeahDollar.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {YeahDollarEngine} from "../src/YeahDollarEngine.sol";

contract DeployYeahDollar is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (YeahDollar, YeahDollarEngine) {
        HelperConfig helperConfig = new HelperConfig();

        (address wEthUsdPriceFeed, address wBtcUsdPriceFeed, address wEth, address wBtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();

        tokenAddresses = [wEth, wBtc];
        priceFeedAddresses = [wEthUsdPriceFeed, wBtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        YeahDollar yeahDollar = new YeahDollar();
        YeahDollarEngine yeahDollarEngine =
            new YeahDollarEngine(tokenAddresses, priceFeedAddresses, address(yeahDollar));
        yeahDollar.transferOwnership(address(yeahDollarEngine));
        vm.stopBroadcast();
        return (yeahDollar, yeahDollarEngine);
    }
}
