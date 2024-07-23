// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;
// pragma solidity >=0.6.2 <0.9.0;

// ---------------------------< IMPORTS
// >------------------------------------------------------------------------------------------------------------------------------>>>
import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title YeahDollar Y$
/// @author Chukwubuike Victory Chime
/// @notice This contract is just the ERC20 implementation of the stablecoin, and it will be governed by the
/// YeahDollarEngine
/// @notice Relative Stability: Pegged to USD
/// @notice Stablity Mechanism: Algorithmic
/// @notice Collateral: Exogenous (wETH and wBTC)
contract YeahDollar is ERC20Burnable, Ownable {
    // >------< Errors >------<
    error YeahDollar__AmountMustBeMoreThanZero();
    error YeahDollar__BurnAmountExceedsBalance();
    error YeahDollar__MustNotBeZeroAddress();

    // ---------------------------< CONSTRUCTOR
    // >------------------------------------------------------------------------------------------------------------------------------>>>
    constructor() ERC20("YeahDollar", "Y$") {}

    // ---------------------------< FUNCTIONS
    // >------------------------------------------------------------------------------------------------------------------------------>>>
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (_amount <= 0) {
            revert YeahDollar__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert YeahDollar__BurnAmountExceedsBalance();
        }

        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert YeahDollar__MustNotBeZeroAddress();
        }
        if (_amount <= 0) {
            revert YeahDollar__AmountMustBeMoreThanZero();
        }

        _mint(_to, _amount);
        return true;
    }
}
