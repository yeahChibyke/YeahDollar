// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity >= 0.8.0;

// ---------------------------< IMPORTS >------------------------------------------------------------------------------------------------------------------------------>>>
import {YeahDollar} from "./YeahDollar.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title YeahDollarEngine Y$E
/// @author Chukwubuike Victory Chime
/// @notice This contract is the core of the Y$ system. It handles all the logic for minting and redeeming Y$, as well as depositing and withdrawing collateral
/// @notice The Y$E is designed to be as minimal as possible, and ensure the maintenance of 1 Y$ == 1 USD at all times
/// @notice The Y$ system should always be "overcollateralized", at no point should the value of all collateral < the $ backed value of all the Y$
/// @notice This contract is based on the MakerDAO DSS system; it is similar to DAI if DAI had no governance, no fees, and was backed by only wETH and wBTC
contract YeahDollarEngine is ReentrancyGuard {
    // ---------------------------< ERRORS >------------------------------------------------------------------------------------------------------------------------------>>>
    error YeahDollarEngine__ShouldBeMoreThanZero();
    error YeahDollarEngine__TokenAddressesAndPriceFeedAddressMismatch();
    error YeahDollarEngine__NotAllowedToken();
    error YeahDollarEngine__TransferFailed();

    // ---------------------------< STATE VARIABLES >------------------------------------------------------------------------------------------------------------------------------>>>
    mapping(address token => address priceFeeds) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    YeahDollar private immutable i_y$;

    // ---------------------------< EVENTS >------------------------------------------------------------------------------------------------------------------------------>>>
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    // ---------------------------< MODIFIERS >------------------------------------------------------------------------------------------------------------------------------>>>
    modifier shouldBeMoreThanZero(uint256 amount) {
        if (amount == 0) {
            revert YeahDollarEngine__ShouldBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address tokenAddress) {
        if (s_priceFeeds[tokenAddress] == address(0)) {
            revert YeahDollarEngine__NotAllowedToken();
        }
        _;
    }

    // ---------------------------< CONSTRUCTOR >------------------------------------------------------------------------------------------------------------------------------>>>
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address y$Address) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert YeahDollarEngine__TokenAddressesAndPriceFeedAddressMismatch();
        }
        // To setup what pricefeeds are allowed; It will be in USD pairs e.g., ETH/USD, BTC/USD. So, any token that doesn't have a pricefeed is not allowed
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        }

        i_y$ = YeahDollar(y$Address);
    }

    // ---------------------------< FUNCTIONS >------------------------------------------------------------------------------------------------------------------------------>>>
    function depositCollateralAndMintY$() external {}

    /**
     * @param tokenCollateralAddress Address of the token to deposit as collateral
     * @param amountCollateral Amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        shouldBeMoreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;

        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        bool successful = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!successful) {
            revert YeahDollarEngine__TransferFailed();
        }
    }

    function redeemCollateralFor$() external {}

    function redeemCollateral() external {}

    function mintY$() external {}

    function burn$() external {}

    function liquidate() external {}

    function gethealthFactor() external view {}
}
