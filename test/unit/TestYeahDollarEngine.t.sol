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
    YeahDollar yd;
    YeahDollarEngine yde;
    HelperConfig helperConfig;

    address user = makeAddr("user");
    uint256 constant AMOUNT_COLLATERAL = 10e18;
    uint256 constant STARTING_ERC20_BALANCE = 10e18;

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address wEth;
    address wBtc;
    uint256 deployerKey;

    address[] tokenAddresses;
    address[] priceFeedAddresses;

    function setUp() public {
        yde = new YeahDollarEngine(tokenAddresses, priceFeedAddresses, address(yd));
        deployer = new DeployYeahDollar();
        (yd, yde, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, wEth, wBtc, deployerKey) = helperConfig.activeNetworkConfig();

        ERC20Mock(wEth).mint(user, STARTING_ERC20_BALANCE);
        ERC20Mock(wBtc).mint(user, STARTING_ERC20_BALANCE);
    }

    // ---------------------------< CONSTRUCTOR TESTS
    function testRevertIfTokenAndPriceFeedLengthsMismatch() public {
        tokenAddresses.push(wEth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(YeahDollarEngine.YeahDollarEngine__TokenAddressesAndPriceFeedAddressMismatch.selector);
        new YeahDollarEngine(tokenAddresses, priceFeedAddresses, address(yd));
    }

    // ---------------------------< PRICE TESTS

    function testGetEthPerUsdValue() public view {
        uint256 ethAmount = 25e18;
        // according to our mock price, 1ETH = $3500
        uint256 expectedUsdAmount = (ethAmount * 3_500);
        uint256 actualUsdAmount = yde.getUsdValue(wEth, ethAmount);

        console2.log(expectedUsdAmount);
        console2.log(actualUsdAmount);

        assert(expectedUsdAmount == actualUsdAmount);
    }

    function testGetBtcPerUsdValue() public view {
        uint256 btcAmount = 25e18;
        // according to our mock price, 1BTC = $66600
        uint256 expectedUsdAmount = (btcAmount * 66_600);
        uint256 actualUsdAmount = yde.getUsdValue(wBtc, btcAmount);

        console2.log(expectedUsdAmount);
        console2.log(actualUsdAmount);

        assert(expectedUsdAmount == actualUsdAmount);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100e18;
        uint256 expectedEthAmount = usdAmount / 3_500;
        uint256 expectedBtcAmount = usdAmount / 66_600;
        uint256 actualEthAmount = yde.getTokenAmountFromUsd(wEth, usdAmount);
        uint256 actualBtcAmount = yde.getTokenAmountFromUsd(wBtc, usdAmount);

        console2.log("The actual ETH amount is: ", actualEthAmount, "ETH");
        console2.log("The actual BTC amount is: ", actualBtcAmount, "BTC");

        assert(expectedEthAmount == actualEthAmount);
        assert(expectedBtcAmount == actualBtcAmount);
    }

    // modifiers to avoid redundancy
    modifier depositedWEth() {
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(yde), AMOUNT_COLLATERAL);
        yde.depositCollateral(wEth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier depositedWBtc() {
        vm.startPrank(user);
        ERC20Mock(wBtc).approve(address(yde), AMOUNT_COLLATERAL);
        yde.depositCollateral(wBtc, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    // ---------------------------< DEPOSITCOLLATERAL TESTS

    function testRevertIfDepositIsZero() public {
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(yde), AMOUNT_COLLATERAL);

        vm.expectRevert(YeahDollarEngine.YeahDollarEngine__ShouldBeMoreThanZero.selector);
        yde.depositCollateral(wEth, 0);
        vm.stopPrank();
    }

    function testRevertIfUnapprovedToken() public {
        ERC20Mock prankToken = new ERC20Mock("PRANK", "PRANK", user, AMOUNT_COLLATERAL);
        vm.startPrank(user);
        vm.expectRevert(YeahDollarEngine.YeahDollarEngine__NotAllowedToken.selector);
        yde.depositCollateral(address(prankToken), AMOUNT_COLLATERAL);
    }

    function testCanDepositWEthAndGetAccountInfo() public depositedWEth {
        (uint256 totalYDMinted, uint256 collateralValueInUsd) = yde.getAccountInformation(user);

        uint256 expectedYDMinted = 0; // Because we deposited without minting
        uint256 expectedDepositAmount = yde.getTokenAmountFromUsd(wEth, collateralValueInUsd);

        assert(totalYDMinted == expectedYDMinted);
        assert(expectedDepositAmount == AMOUNT_COLLATERAL); // Since we didn't mint our deposit, the deposit amount should equal the AMOUNT_COLLATERAL, which is the amount deposited as per the modifier
    }

    function testCanDepositWBtcAndGetAccountInfo() public depositedWBtc {
        (uint256 totalYDMinted, uint256 collateralValueInUsd) = yde.getAccountInformation(user);

        uint256 expectedYDMinted = 0; // Because we deposited without minting
        uint256 expectedDepositAmount = yde.getTokenAmountFromUsd(wBtc, collateralValueInUsd);

        assert(totalYDMinted == expectedYDMinted);
        assert(expectedDepositAmount == AMOUNT_COLLATERAL); // Since we didn't mint our deposit, the deposit amount should equal the AMOUNT_COLLATERAL, which is the amount deposited as per the modifier
    }

    // ---------------------------< MINT TESTS

    function testCanMintAndGetAccountInfo() public depositedWEth {
        uint256 mintAmount = 5e18;

        vm.startPrank(user);

        yde.mintYD(mintAmount);
        (uint256 totalYDMinted, uint256 collateralValueInUsd) = yde.getAccountInformation(user);
        uint256 expectedDepositAmount = yde.getTokenAmountFromUsd(wEth, collateralValueInUsd);
        uint256 userCollateralBalance = expectedDepositAmount - mintAmount;

        assert(totalYDMinted == mintAmount);
        assert(expectedDepositAmount == AMOUNT_COLLATERAL);
        assert(userCollateralBalance == 5e18);
    }

   

    function testRevertIfWantToMintZero() public depositedWEth {
        vm.startPrank(user);

        vm.expectRevert(YeahDollarEngine.YeahDollarEngine__ShouldBeMoreThanZero.selector);
        yde.mintYD(0);
    }

    // ---------------------------<  TESTS
}
