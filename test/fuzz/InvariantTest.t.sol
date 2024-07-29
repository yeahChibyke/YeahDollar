// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

// This will contain our invariants (properties of our system that should never fail)

import {Test, console2} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {YeahDollarEngine} from "../../src/YeahDollarEngine.sol";
import {YeahDollar} from "../../src/YeahDollar.sol";

contract InvariantTest is StdInvariant, Test {
    YeahDollar yd;
    YeahDollarEngine yde;

    address[] tokenAddresses;
    address[] priceFeedAddresses;

    function setUp() public {
        yde = new YeahDollarEngine(tokenAddresses, priceFeedAddresses, address(yd));

        targetContract(address(yde));
    }
}
