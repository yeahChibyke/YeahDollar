// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {YeahDollar} from "../../src/YeahDollar.sol";
import {YeahDollarEngine} from "../../src/YeahDollarEngine.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract Handler is Test {
    YeahDollar yd;
    YeahDollarEngine yde;

    ERC20Mock wEth;
    ERC20Mock wBtc;

    uint256 constant MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(YeahDollar _yd, YeahDollarEngine _yde) {
        yd = _yd;
        yde = _yde;

        address[] memory collateralTokens = yde.getCollateralTokens();
        wEth = ERC20Mock(collateralTokens[0]);
        wBtc = ERC20Mock(collateralTokens[1]);
    }

    /**
     * @dev This function is a lil bit different than the depositCollateral function in the YeahDollarEngine, but the randomization is still maintained. We want it to deposit random collateralls that are valid collaterals
     */
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(yde), amountCollateral);
        yde.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    function mintYd(uint256 amountToMint) public {
        (uint256 totalYDMinted, uint256 collateralValueInUsd) = yde.getAccountInformation(msg.sender);
        int256 maxYdThatCanBeMinted = (int256(collateralValueInUsd) / 2) - int256(totalYDMinted);
        if (maxYdThatCanBeMinted < 0) return;
        amountToMint = bound(amountToMint, 0, uint256(maxYdThatCanBeMinted));
        if (amountToMint == 0) return;
        vm.prank(msg.sender);
        yde.mintYD(amountToMint);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralThatUserCanRedeem = yde.getCollateralBalanceOfUser(address(collateral), msg.sender); // In the YD engine,this particular function, in the order of parameter input, address of user (msg.sender in this case) comes before token (address(colateral)). But, if I write getCollateralBalanceOfUser(msg.sender, address(collateral)), test fails. And if I switch the order of paramter input in the getCollateralBalanceOfUser() function in YD engine, the test also fails. Why????
        amountCollateral = bound(amountCollateral, 0, maxCollateralThatUserCanRedeem);
        if (amountCollateral == 0) {
            return;
        }

        yde.redeemCollateral(address(collateral), amountCollateral);
    }

    // >---------> HELPER FUNCTIONS
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) return wEth;
        return wBtc;
    }
}
