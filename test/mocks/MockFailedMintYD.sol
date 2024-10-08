// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;
// pragma solidity >=0.6.2 <0.9.0;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockFailedMintYD is ERC20Burnable, Ownable {
    error YeahDollar__AmountMustBeMoreThanZero();
    error YeahDollar__BurnAmountExceedsBalance();
    error YeahDollar__NotZeroAddress();

    constructor() ERC20("YeahDollar", "Y$") {}

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
            revert YeahDollar__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert YeahDollar__AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return false;
    }
}
