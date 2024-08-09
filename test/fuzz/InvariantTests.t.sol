// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

// This will contain our invariants (properties of our system that should never fail)

import {Test, console2} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {YeahDollarEngine} from "../../src/YeahDollarEngine.sol";
import {YeahDollar} from "../../src/YeahDollar.sol";
import {DeployYeahDollar} from "../../script/DeployYeahDollar.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantTests is StdInvariant, Test {
    YeahDollar yd;
    YeahDollarEngine yde;
    DeployYeahDollar deployer;
    HelperConfig helperConfig;
    Handler handler;

    address wEth;
    address wBtc;

    function setUp() external {
        deployer = new DeployYeahDollar();
        (yd, yde, helperConfig) = deployer.run();
        (,, wEth, wBtc,) = helperConfig.activeNetworkConfig();

        handler = new Handler(yd, yde);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupplyOfYDMinted() public view {
        // get the value of all the collateral in the protocol and compare it to the value of the total supply of YD minted
        uint256 totalSupplyOfYDMinted = yd.totalSupply();
        uint256 totalWEthDeposited = IERC20(wEth).balanceOf(address(yde));
        uint256 totalWBtcDeposited = IERC20(wBtc).balanceOf(address(yde));

        uint256 wEthValueInUsd = yde.getUsdValue(wEth, totalWEthDeposited);
        uint256 wBtcValueInUsd = yde.getUsdValue(wBtc, totalWBtcDeposited);
        uint256 sum = wEthValueInUsd + wBtcValueInUsd;

        console2.log("This is the value of wEth in Usd: ", wEthValueInUsd);
        console2.log("This is the value of wBtc in Usd: ", wBtcValueInUsd);
        console2.log("This is the value of the sum in Usd: ", sum);
        console2.log("This is the total supply of YD minted: ", totalSupplyOfYDMinted);
        console2.log("This is the number of times the mint function was called: ", handler.numberOfTimesMintIsCalled());

        assert(sum >= totalSupplyOfYDMinted);
    }

    function invariant_gettersShouldNotRevert() public view{
        yde.getPrecision();
        yde.getAdditionalFeedPrecision();
        yde.getLiquidationThreshold();
        yde.getLiquidationBonus();
        yde.getLiquidationPrecision();
        yde.getMinHealthFactor();
        yde.getCollateralTokens();
        yde.getYD();
        yde.getTokenAmountFromUsd(wEth, 50);
        yde.getTokenAmountFromUsd(wBtc, 50);
        yde.getAccountInformation(msg.sender);
        yde.getAccountCollateralValue(msg.sender);
        yde.getUsdValue(wEth, 50);
        yde.getUsdValue(wBtc, 50);
        yde.getCollateralBalanceOfUser(wEth, msg.sender);
        yde.getCollateralBalanceOfUser(wBtc, msg.sender);
        yde.getCollateralTokenPriceFeed(wEth);
        yde.getCollateralTokenPriceFeed(wBtc);
        yde.getHealthFactor(msg.sender);
    }
}
