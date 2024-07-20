// SPDX-License-Identifier: SEE LICENSE IN LICENSE
// pragma solidity 0.8.19;
pragma solidity >=0.6.2 <0.9.0;

// ---------------------------< IMPORTS >------------------------------------------------------------------------------------------------------------------------------>>>
import {YeahDollar} from "./YeahDollar.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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
    error YeahDollarEngine__HealthFactorIsBroken(uint256 healthFactor);
    error YeahDollarEngine__MintFailed();

    // ---------------------------< STATE VARIABLES >------------------------------------------------------------------------------------------------------------------------------>>>
    // >------< MAPPINGS >-----<
    /// @dev Mapping of token address to pricefeed address
    mapping(address token => address priceFeeds) private s_priceFeeds;
    /// @dev Mapping of user to amount of collateral deposited
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    /// @dev Mapping of user to amount of Y$ minted
    mapping(address user => uint256 amountY$Minted) private s_Y$Minted;
    // >------< IMMUTABLES >-----<
    YeahDollar private immutable i_y$;
    // >------< ADDRESSES >-----<
    address[] private s_collateralTokens;
    // >------< CONSTANTS >-----<
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

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
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_y$ = YeahDollar(y$Address);
    }

    // ---------------------------< FUNCTIONS >------------------------------------------------------------------------------------------------------------------------------>>>
    // >------< EXTERNAL FUNCTIONS >-----<
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

        bool transferSuccessful =
            IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (transferSuccessful) {
            revert YeahDollarEngine__TransferFailed();
        }
    }

    function redeemCollateralForY$() external {}

    function redeemCollateral() external {}

    /**
     * @param amountY$ToMint Amount of Y$ to mint
     * @notice Minting will fail if collateral value > minimum threshold
     */
    function mintY$(uint256 amountY$ToMint) external shouldBeMoreThanZero(amountY$ToMint) nonReentrant {
        s_Y$Minted[msg.sender] += amountY$ToMint;

        _revertIfHealthFactorIsBroken(msg.sender);

        bool mintSuccessful = i_y$.mint(msg.sender, amountY$ToMint);

        if (!mintSuccessful) {
            revert YeahDollarEngine__MintFailed();
        }
    }

    function burn$() external {}

    function liquidate() external {}

    function gethealthFactor() external view {}

    // >------< PUBLIC FUNCTIONS >-----<
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 answer,,,) = priceFeed.latestRoundData();
        return ((uint256(answer) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    // >------< PRIVATE & INTERNAL VIEW FUNCTIONS >-----<
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalY$Minted, uint256 collateralValueInUsd)
    {
        totalY$Minted = s_Y$Minted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * Returns how close to liquidation a user is
     * If a user goes below 1, they are at risk of getting liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalY$Minted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalY$Minted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);

        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert YeahDollarEngine__HealthFactorIsBroken(userHealthFactor);
        }
    }
}
