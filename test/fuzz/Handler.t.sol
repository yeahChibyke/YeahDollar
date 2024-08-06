// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {YeahDollar} from "../../src/YeahDollar.sol";
import {YeahDollarEngine} from "../../src/YeahDollarEngine.sol";

contract Handler is Test {
    YeahDollar yd;
    YeahDollarEngine yde;

    constructor(YeahDollar _yd, YeahDollarEngine _yde) {
        yd = _yd;
        yde = _yde;
    }

    /**
     * @dev This function is a lil bit different than the depositCollateral function in the YeahDollarEngine, but the randomization is still maintained
     */
    function depositCollateral(address collateral, uint256 amountCollateral) public {
        yde.depositCollateral(collateral, amountCollateral);
    }
}
