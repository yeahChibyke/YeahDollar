// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

// This Handler is basically a manager to narrow down the manner in which functions are called to ensure that our invariant tests give us the best results. We don't want to waste runs.

import {Test, console2} from "forge-std/Test.sol";
import {YeahDollarEngine} from "../../src/YeahDollarEngine.sol";
import {YeahDollar} from "../../src/YeahDollar.sol";

contract Handler is Test {
    YeahDollar yd;
    YeahDollarEngine yde;

    constructor(YeahDollarEngine _yde, YeahDollar _yd) {
        yde = _yde;
        yd = _yd;
    }

    function depositCollateral(address collateralToken, uint256 collateralAmount) public {
        yde.depositCollateral(collateralToken, collateralAmount);
    }
}
