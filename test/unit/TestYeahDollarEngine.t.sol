// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity >= 0.6.0 < 0.9.0;

import {Test, console2} from "forge-std/Test.sol";
import {YeahDollarEngine} from "../../src/YeahDollarEngine.sol";
import {DeployYeahDollar} from "../../script/DeployYeahDollar.s.sol";
import {YeahDollar} from "../../src/YeahDollar.sol";

contract TestYeahDollarEngine is Test {
    DeployYeahDollar deployer;

    function setUp() public {
        deployer = new DeployYeahDollar();
    }
}
