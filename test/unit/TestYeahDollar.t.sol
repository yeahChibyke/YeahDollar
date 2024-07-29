// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {YeahDollar} from "../../src/YeahDollar.sol";

contract TestYeahDollar is Test {
    YeahDollar yd;

    // address user = address(this);
    // address receiver = makeAddr("receiver");
    address owner;
    address receiver;

    function setUp() external {
        yd = new YeahDollar();

        owner = yd.owner();
        receiver = address(this);
    }

    function testConstructor() public view {
        assertEq(yd.name(), "YeahDollar");
        assertEq(yd.symbol(), "Y$");
    }

    function testYDMintSuccessful() public {
        vm.prank(owner);
        yd.mint(receiver, 100);
        assert(yd.balanceOf(receiver) == 100);
    }

    function testMustRevertIfWantToMintYDWithZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(YeahDollar.YeahDollar__AmountMustBeMoreThanZero.selector);
        yd.mint(receiver, 0);
    }

    function testMustRevertIfWantToMintYDToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(YeahDollar.YeahDollar__MustNotBeZeroAddress.selector);
        yd.mint(address(0), 100);
    }

    function testYDBurnSuccessful() public {
        vm.prank(owner);
        yd.mint(receiver, 100);

        uint256 receiverBalBeforeBurn = yd.balanceOf(receiver);

        yd.burn(100);

        uint256 receiverBalAfterBurn = yd.balanceOf(receiver);

        assert(receiverBalBeforeBurn == 100);
        assert(receiverBalAfterBurn < receiverBalBeforeBurn);
    }

    function testRevertIfWantToBurnYDAmountThatIsZero() public {
        vm.prank(owner);
        yd.mint(receiver, 100);

        uint256 receiverBalBeforeBurn = yd.balanceOf(receiver);

        vm.expectRevert(YeahDollar.YeahDollar__AmountMustBeMoreThanZero.selector);
        yd.burn(0);

        uint256 receiverBalAfterFailedBurn = yd.balanceOf(receiver);

        assert(receiverBalBeforeBurn == receiverBalAfterFailedBurn);
    }

    function testRevertIfWantToBurnMoreThanYDBalance() public {
        vm.prank(owner);
        yd.mint(receiver, 100);

        uint256 receiverBalBeforeBurn = yd.balanceOf(receiver);

        vm.expectRevert(YeahDollar.YeahDollar__BurnAmountExceedsBalance.selector);
        yd.burn(200);

        uint256 receiverBalAfterFailedBurn = yd.balanceOf(receiver);

        assert(receiverBalBeforeBurn == receiverBalAfterFailedBurn);
    }
}
