// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity >= 0.6.0 < 0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import {YeahDollarEngine} from "../../src/YeahDollarEngine.sol";
import {DeployYeahDollar} from "../../script/DeployYeahDollar.s.sol";
import {YeahDollar} from "../../src/YeahDollar.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract TestYeahDollarEngine is Test {
    DeployYeahDollar deployer;
    YeahDollar yeahDollar;
    YeahDollarEngine yeahDollarEngine;
    HelperConfig helperConfig;

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address wEth;
    address wBtc;

    function setUp() public {
        deployer = new DeployYeahDollar();
        (yeahDollar, yeahDollarEngine, helperConfig) = deployer.run();

        (ethUsdPriceFeed, btcUsdPriceFeed, wEth, wBtc) = helperConfig.activeNetworkConfig();
    }

    // ---------------------------< PRICE TESTS

    function testGetEthPerUsdValue() public view {
        uint256 ethAmount = 25e18;
        // according to our mock price, 1ETH = $3500
        uint256 expectedUsdAmount = (ethAmount * 3500);
        uint256 actualUsdAmount = yeahDollarEngine.getUsdValue(wEth, ethAmount);

        assert(expectedUsdAmount == actualUsdAmount);
    }
}
