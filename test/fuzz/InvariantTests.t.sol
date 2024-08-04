// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

// This will contain our invariants (properties of our system that should never fail)

import {Test} from "forge-std/Test.sol";
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
    HelperConfig helperConfig;
    Handler handler;

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address wEth;
    address wBtc;

    function setUp() external {
        DeployYeahDollar deployer = new DeployYeahDollar();
        (yd, yde, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, wEth, wBtc,) = helperConfig.activeNetworkConfig();

        handler = new Handler(yde, yd);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupplyOfYDMinted() public view {
        // get the value of all the collateral in the protocol and compare it to the value of the total supply of YD minted
        uint256 totalSupplyOfYDMinted = yd.totalSupply();
        uint256 totalWEthDeposited = IERC20(wEth).balanceOf(address(yde));
        uint256 totalWBtcDeposited = IERC20(wBtc).balanceOf(address(yde));

        uint256 wEthValueInUsd = yde.getUsdValue(wEth, totalWEthDeposited);
        uint256 wBtcValueInUsd = yde.getUsdValue(wBtc, totalWBtcDeposited);

        assert(wEthValueInUsd + wBtcValueInUsd > totalSupplyOfYDMinted);
    }
}
