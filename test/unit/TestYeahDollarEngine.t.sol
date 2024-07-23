// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;
// pragma solidity >= 0.6.0 < 0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import {YeahDollarEngine} from "../../src/YeahDollarEngine.sol";
import {DeployYeahDollar} from "../../script/DeployYeahDollar.s.sol";
import {YeahDollar} from "../../src/YeahDollar.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract TestYeahDollarEngine is Test {
    DeployYeahDollar deployer;
    YeahDollar yeahDollar;
    YeahDollarEngine yeahDollarEngine;
    HelperConfig helperConfig;

    address Chibyke = makeAddr("Chibyke");
    uint256 constant AMOUNT_COLLATERAL = 50e18;
    uint256 constant STARTING_ERC20_BALANCE = 50e18;

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address wEth;
    address wBtc;
    uint256 deployerKey;

    address[] tokenAddresses;
    address[] priceFeedAddresses;

    function setUp() public {
        yeahDollarEngine = new YeahDollarEngine(tokenAddresses, priceFeedAddresses, address(yeahDollar));
        deployer = new DeployYeahDollar();
        (yeahDollar, yeahDollarEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, wEth, wBtc, deployerKey) = helperConfig.activeNetworkConfig();

        ERC20Mock(wEth).mint(Chibyke, STARTING_ERC20_BALANCE);
    }

    // ---------------------------< PRICE TESTS

    function testGetEthPerUsdValue() public view {
        uint256 ethAmount = 25e18;
        // according to our mock price, 1ETH = $3500
        uint256 expectedUsdAmount = (ethAmount * 3500);
        uint256 actualUsdAmount = yeahDollarEngine.getUsdValue(wEth, ethAmount);

        console2.log(expectedUsdAmount);
        console2.log(actualUsdAmount);

        assert(expectedUsdAmount == actualUsdAmount);
    }

    function testGetBtcPerUsdValue() public view {
        uint256 btcAmount = 25e18;
        // according to our mock price, 1BTC = $66600
        uint256 expectedUsdAmount = (btcAmount * 66_600);
        uint256 actualUsdAmount = yeahDollarEngine.getUsdValue(wBtc, btcAmount);

        console2.log(expectedUsdAmount);
        console2.log(actualUsdAmount);

        assert(expectedUsdAmount == actualUsdAmount);
    }

    // ---------------------------< DEPOSITCOLLATERAL TESTS
    function testRevertIfDepositIsZero() public {
        vm.startPrank(Chibyke);
        ERC20Mock(wEth).approve(wEth, AMOUNT_COLLATERAL);

        vm.expectRevert(YeahDollarEngine.YeahDollarEngine__ShouldBeMoreThanZero.selector);
        yeahDollarEngine.depositCollateral(wEth, 0);
        vm.stopPrank();
    }
}
