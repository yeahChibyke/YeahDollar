// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;
// pragma solidity >= 0.6.0 < 0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import {YeahDollarEngine} from "../../src/YeahDollarEngine.sol";
import {DeployYeahDollar} from "../../script/DeployYeahDollar.s.sol";
import {YeahDollar} from "../../src/YeahDollar.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {MockFailedMintYD} from "../mocks/MockFailedMintYD.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";
import {MockFailedTransfer} from "../mocks/MockFailedTransfer.sol";

contract TestYeahDollarEngine is Test {
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    ); // If redeemedFrom != redeemedTo, then it was liquidated

    DeployYeahDollar deployer;
    YeahDollar yd;
    YeahDollarEngine yde;
    HelperConfig helperConfig;

    uint256 mintAmount = 100e18; // Remember, mint amount is in YD; which is in a ratio of 1 YD == 1 $. So this is not 100 wETH, but actually 100 YD (or 100 $)

    uint256 constant AMOUNT_COLLATERAL = 10e18; // Remember, deposits are in either wETH or wBTC. So this could either be 10 wETH or 10 wBTC
    uint256 constant STARTING_ERC20_BALANCE = 10e18;
    uint256 constant MIN_HEALTH_FACTOR = 1e18;
    uint256 constant LIQUIDATION_THRESHOLD = 50;

    address user = makeAddr("user");

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address wEth;
    address wBtc;
    uint256 deployerKey;

    function setUp() public {
        yde = new YeahDollarEngine(tokenAddresses, priceFeedAddresses, address(yd));
        deployer = new DeployYeahDollar();
        (yd, yde, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, wEth, wBtc, deployerKey) = helperConfig.activeNetworkConfig();

        ERC20Mock(wEth).mint(user, STARTING_ERC20_BALANCE);
        ERC20Mock(wBtc).mint(user, STARTING_ERC20_BALANCE);
    }

    // ---------------------------< CONSTRUCTOR TESTS

    address[] tokenAddresses;
    address[] priceFeedAddresses;

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

    // This test needs it own setup
    function testRevertIfTransferFromFails() public {
        // Arrange setup
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransferFrom mockYD = new MockFailedTransferFrom();
        tokenAddresses = [address(mockYD)];
        priceFeedAddresses = [ethUsdPriceFeed];

        vm.prank(owner);
        YeahDollarEngine mockYDE = new YeahDollarEngine(tokenAddresses, priceFeedAddresses, address(mockYD));
        mockYD.mint(user, AMOUNT_COLLATERAL);

        vm.prank(owner);
        mockYD.transferOwnership(address(mockYDE));

        // Arrange user
        vm.prank(user);
        ERC20Mock(address(mockYD)).approve(address(mockYDE), AMOUNT_COLLATERAL);

        // Act / Assert
        vm.expectRevert(YeahDollarEngine.YeahDollarEngine__TransferFailed.selector);
        mockYDE.depositCollateral(address(mockYD), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    // ---------------------------< MINT TESTS

    function testCanMintAndGetAccountInfo() public depositedWEth {
        uint256 amountToBeMinted = 5e18;

        vm.startPrank(user);

        yde.mintYD(amountToBeMinted);
        (uint256 totalYDMinted, uint256 collateralValueInUsd) = yde.getAccountInformation(user);
        uint256 expectedDepositAmount = yde.getTokenAmountFromUsd(wEth, collateralValueInUsd);
        uint256 userCollateralBalance = expectedDepositAmount - amountToBeMinted;

        assert(totalYDMinted == amountToBeMinted);
        assert(expectedDepositAmount == AMOUNT_COLLATERAL);
        assert(userCollateralBalance == 5e18);
    }

    function testRevertIfWantToMintZero() public depositedWEth {
        vm.startPrank(user);

        vm.expectRevert(YeahDollarEngine.YeahDollarEngine__ShouldBeMoreThanZero.selector);
        yde.mintYD(0);
    }

    function testRevertIfMintAmountBreaksHealthFactor() public depositedWEth {
        (, int256 answer,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        mintAmount = (AMOUNT_COLLATERAL * (uint256(answer) * yde.getAdditionalFeedPrecision())) / yde.getPrecision();

        vm.startPrank(user);

        uint256 expectedHealthFactor = yde.calculateHealthFactor(mintAmount, yde.getUsdValue(wEth, AMOUNT_COLLATERAL));

        vm.expectRevert(
            abi.encodeWithSelector(
                YeahDollarEngine.YeahDollarEngine__HealthFactorIsBroken.selector, expectedHealthFactor
            )
        );
        yde.mintYD(mintAmount);

        vm.stopPrank();
    }

    // This test needs its own setup
    function testRevertIfMintFails() public {
        // Arrange the setup
        MockFailedMintYD mockYD = new MockFailedMintYD();
        tokenAddresses = [wEth];
        priceFeedAddresses = [ethUsdPriceFeed];
        address owner = msg.sender;

        vm.prank(owner);
        YeahDollarEngine mockYDE = new YeahDollarEngine(tokenAddresses, priceFeedAddresses, address(mockYD));
        mockYD.transferOwnership(address(mockYDE));

        // Arrange user
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(mockYDE), AMOUNT_COLLATERAL);

        vm.expectRevert(YeahDollarEngine.YeahDollarEngine__MintFailed.selector);
        mockYDE.depositCollateralAndMintYD(wEth, AMOUNT_COLLATERAL, mintAmount);

        vm.stopPrank();
    }

    // ---------------------------< DEPOSITCOLLATERALANDMINTYD TESTS

    // This test fails if I use any of the deposit modifiers I created (depositedWEth or depositedWBtc)
    // Why?????????
    function testRevertIfMintedYDBreaksHealthFactor() public {
        (, int256 answer,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        mintAmount = (AMOUNT_COLLATERAL * (uint256(answer) * yde.getAdditionalFeedPrecision())) / yde.getPrecision();

        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(yde), AMOUNT_COLLATERAL);

        uint256 expectedHealthFactor = yde.calculateHealthFactor(mintAmount, yde.getUsdValue(wEth, AMOUNT_COLLATERAL));

        vm.expectRevert(
            abi.encodeWithSelector(
                YeahDollarEngine.YeahDollarEngine__HealthFactorIsBroken.selector, expectedHealthFactor
            )
        );
        yde.depositCollateralAndMintYD(wEth, AMOUNT_COLLATERAL, mintAmount);

        vm.stopPrank();
    }

    modifier depositedCollateralAndMintedYD() {
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(yde), AMOUNT_COLLATERAL);
        yde.depositCollateralAndMintYD(wEth, AMOUNT_COLLATERAL, mintAmount);
        vm.stopPrank();
        _;
    }

    function testCanMintWithDepositedCollateral() public depositedCollateralAndMintedYD {
        uint256 userBalance = yd.balanceOf(user);

        console2.log(userBalance);

        assert(userBalance == mintAmount);
    }

    // ---------------------------< BURNYD TESTS

    function testRevertIfBurnAmountisZero() public depositedCollateralAndMintedYD {
        vm.startPrank(user);

        vm.expectRevert(YeahDollarEngine.YeahDollarEngine__ShouldBeMoreThanZero.selector);
        yde.burnYD(0);

        vm.stopPrank();
    }

    function testCannotBurnMoreThanUserHasMinted() public {
        vm.startPrank(user);

        vm.expectRevert();
        yde.burnYD(1);

        vm.stopPrank();
    }

    function testCanBurnYD() public depositedCollateralAndMintedYD {
        uint256 userYDBalanceBeforeBurning = yd.balanceOf(user);
        assert(userYDBalanceBeforeBurning == mintAmount);

        vm.startPrank(user);

        yd.approve(address(yde), mintAmount);
        yde.burnYD(mintAmount);

        vm.stopPrank();

        uint256 userYDBalanceAfterBurning = yd.balanceOf(user);

        assert(userYDBalanceAfterBurning == 0);
        assert(userYDBalanceBeforeBurning > userYDBalanceAfterBurning);
    }

    // ---------------------------< REDEEMCOLLATERAL TESTS

    function testRevertIfRedeemAmountIsZero() public depositedWEth {
        vm.startPrank(user);

        vm.expectRevert(YeahDollarEngine.YeahDollarEngine__ShouldBeMoreThanZero.selector);
        yde.redeemCollateral(wEth, 0);

        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositedWEth {
        vm.startPrank(user);

        yde.redeemCollateral(wEth, AMOUNT_COLLATERAL);
        uint256 userCollateralBalance = ERC20Mock(wEth).balanceOf(user);

        assert(userCollateralBalance == AMOUNT_COLLATERAL);

        vm.stopPrank();
    }

    // This test needs its own setup
    function testRevertIfTransferFails() public {
        // Arrange
        address owner = msg.sender;

        vm.startPrank(owner);

        MockFailedTransfer mockYD = new MockFailedTransfer();
        tokenAddresses = [address(mockYD)];
        priceFeedAddresses = [ethUsdPriceFeed];
        YeahDollarEngine mockYDE = new YeahDollarEngine(tokenAddresses, priceFeedAddresses, address(mockYD));
        mockYD.mint(user, AMOUNT_COLLATERAL);
        mockYD.transferOwnership(address(mockYDE));

        vm.stopPrank();

        // Arrange user
        vm.startPrank(user);
        ERC20Mock(address(mockYD)).approve(address(mockYDE), AMOUNT_COLLATERAL);

        // Act / Assert
        mockYDE.depositCollateral(address(mockYD), AMOUNT_COLLATERAL);

        vm.expectRevert(YeahDollarEngine.YeahDollarEngine__RedeemFailed.selector);
        mockYDE.redeemCollateral(address(mockYD), AMOUNT_COLLATERAL);

        vm.stopPrank();
    }

    // will write you later
    // function testWillEmitCollateralRedeemedEventCorrectly() public depositedWEth {}

    // ---------------------------< REDEEMCOLLATERALFORYD TESTS

    function testRevertIfWantToRedeemZero() public depositedCollateralAndMintedYD {
        vm.startPrank(user);

        yd.approve(address(yde), 5);
        vm.expectRevert(YeahDollarEngine.YeahDollarEngine__ShouldBeMoreThanZero.selector);
        yde.redeemCollateralForYD(wEth, 0, mintAmount);

        vm.stopPrank();
    }

    function testRevertIfWantToRedeemUnapprovedToken() public depositedCollateralAndMintedYD {
        ERC20Mock prankToken = new ERC20Mock("PRANK", "PRANK", user, AMOUNT_COLLATERAL);

        vm.startPrank(user);

        yd.approve(address(yde), 5);
        vm.expectRevert(YeahDollarEngine.YeahDollarEngine__NotAllowedToken.selector);
        yde.redeemCollateralForYD(address(prankToken), AMOUNT_COLLATERAL, mintAmount);

        vm.stopPrank();
    }

    function testCanRedeemDepositedCollateral() public {
        vm.startPrank(user);

        ERC20Mock(wEth).approve(address(yde), AMOUNT_COLLATERAL);
        yde.depositCollateralAndMintYD(wEth, AMOUNT_COLLATERAL, mintAmount);
        yd.approve(address(yde), mintAmount);
        yde.redeemCollateralForYD(wEth, AMOUNT_COLLATERAL, mintAmount);

        vm.stopPrank();

        uint256 userYDBalance = yd.balanceOf(user);
        assert(userYDBalance == 0);
    }

    // ---------------------------< LIQUIDATION TESTS

    

    // ---------------------------< VIEW AND PURE TESTS

    function testGetCollateralPriceFeed() public view {
        address ethPriceFeed = yde.getCollateralTokenPriceFeed(wEth);
        address btcPriceFeed = yde.getCollateralTokenPriceFeed(wBtc);

        assert(ethPriceFeed == ethUsdPriceFeed);
        assert(btcPriceFeed == btcUsdPriceFeed);
    }

    function testGetCollateralTokens() public view {
        address[] memory collateralTokens = yde.getCollateralTokens();

        assert(collateralTokens[0] == wEth);
        assert(collateralTokens[1] == wBtc);
    }

    function testGetminHealthFactor() public view {
        uint256 actualMinHealthFactor = yde.getMinHealthFactor();

        assert(actualMinHealthFactor == MIN_HEALTH_FACTOR);
    }

    function testGetLiquidationThreshold() public view {
        uint256 actualLiquidationThreshold = yde.getLiquidationThreshold();

        assert(actualLiquidationThreshold == LIQUIDATION_THRESHOLD);
    }

    function testGetYD() public view {
        address ydAddress = yde.getYD();

        assert(ydAddress == address(yd));
    }

    function testGetLiquidationPrecision() public view {
        uint256 expectedLiquidationPrecision = 100;
        uint256 actualLiquidationPrecision = yde.getLiquidationPrecision();

        assertEq(actualLiquidationPrecision, expectedLiquidationPrecision);
    }

    function testGetCollateralBalanceOfUser() public depositedWEth {
        uint256 collateralBalanceOfUser = yde.getCollateralBalanceOfUser(user, wEth);

        assert(collateralBalanceOfUser == AMOUNT_COLLATERAL);
    }

    function testGetAccountCollateralValue() public depositedWEth {
        uint256 collateralValue = yde.getAccountCollateralValue(user);
        uint256 expectedCollateralValue = yde.getUsdValue(wEth, AMOUNT_COLLATERAL);

        assertEq(collateralValue, expectedCollateralValue);
    }
}
