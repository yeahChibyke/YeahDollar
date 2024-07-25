// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;
// pragma solidity >=0.6.2 <0.9.0;

// ---------------------------< IMPORTS
import {YeahDollar} from "./YeahDollar.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/// @title YeahDollarEngine YDE
/// @author Chukwubuike Victory Chime
/// @notice This contract is the core of the YD system. It handles all the logic for minting and redeeming YD, as well
/// as depositing and withdrawing collateral
/// @notice The YDE is designed to be as minimal as possible, and ensure the maintenance of 1 YD == 1 USD at all times
/// @notice The YD system should always be "overcollateralized", at no point should the value of all collateral < the D
/// backed value of all the YD
/// @notice This contract is based on the MakerDAO DSS system; it is similar to DAI if DAI had no governance, no fees,
/// and was backed by only wETH and wBTC
contract YeahDollarEngine is ReentrancyGuard {
    // ---------------------------< ERRORS
    error YeahDollarEngine__ShouldBeMoreThanZero();
    error YeahDollarEngine__TokenAddressesAndPriceFeedAddressMismatch();
    error YeahDollarEngine__NotAllowedToken();
    error YeahDollarEngine__TransferFailed();
    error YeahDollarEngine__HealthFactorIsBroken(uint256 healthFactor);
    error YeahDollarEngine__MintFailed();
    error YeahDollarEngine__RedeemFailed();
    error YeahDollarEngine__HealthFactorIsHealthy();
    error YeahDollarEngine__HealthFactorNotIproved();
    error YeahDollarEngine__AmountToMintMoreThanDepositCollateral();

    // ---------------------------< STATE VARIABLES
    // >------< CONSTANTS >-----<
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private LIQUIDATION_BONUS = 10; // This mean a 10% bonus

    // >------< MAPPINGS >-----<
    /// @dev Mapping of token address to pricefeed address
    mapping(address token => address priceFeeds) private s_priceFeeds;
    /// @dev Mapping of user to amount of collateral deposited
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    /// @dev Mapping of user to amount of YD minted
    mapping(address user => uint256 amountYDMinted) private s_YDMinted;

    // >------< IMMUTABLES >-----<
    YeahDollar private immutable i_yd;

    // >------< ADDRESSES >-----<
    address[] private s_collateralTokens;

    // >------------------------------------------------------------------------------------------------------------------------------>>>

    // ---------------------------< EVENTS
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    // ---------------------------< MODIFIERS
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

    // Added this
    modifier mintAmountMustBeLessOrEqualToUserDepositCollateral(uint256 amount, address tokenCollateralAddress) {
        uint256 depCollateral = s_collateralDeposited[msg.sender][tokenCollateralAddress];
        if (amount > depCollateral) {
            revert YeahDollarEngine__AmountToMintMoreThanDepositCollateral();
        }
        _;
    }

    // >------------------------------------------------------------------------------------------------------------------------------>>>

    // ---------------------------< CONSTRUCTOR
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address ydAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert YeahDollarEngine__TokenAddressesAndPriceFeedAddressMismatch();
        }
        // To setup what pricefeeds are allowed; It will be in USD pairs e.g., ETH/USD, BTC/USD. So, any token that
        // doesn't have a pricefeed is not allowed
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_yd = YeahDollar(ydAddress);
    }

    // >------------------------------------------------------------------------------------------------------------------------------>>>

    // ---------------------------< FUNCTIONS
    // >------< EXTERNAL FUNCTIONS >-----<
    /**
     * @param tokenCollateralAddress Address of the token being deposited as collateral
     * @param amountCollateral Amount of collateral being deposited
     * @param amountYDToMint Amount of YD to be minted
     * @notice This function will deposit collateral and mint YD in one transaction
     */
    function depositCollateralAndMintYD(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountYDToMint
    ) external mintAmountMustBeLessOrEqualToUserDepositCollateral(amountYDToMint, tokenCollateralAddress) {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintYD(amountYDToMint, tokenCollateralAddress);
    }

    /**
     * @param tokenCollateralAddress Address of the token of the collateral to be redeemed
     * @param amountCollateral Amount of collateral to be redeemed
     * @param amountYDToBurn Amount of YD to be burnt
     * @notice This function will burn YD and redeem/withdraw underlying collateral in one transaction
     */
    function redeemCollateralForYD(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountYDToBurn)
        external
    {
        _burnYD(amountYDToBurn, msg.sender, msg.sender);
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @param tokenCollateralAddress Address of the token of the collateral to be redeemed
     * @param amountCollateral Amount of collateral to be redeemed
     * @notice This function will redeem collateral when called
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        shouldBeMoreThanZero(amountCollateral)
        nonReentrant
        isAllowedToken(tokenCollateralAddress)
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @param amountYDToBurn Amount of YD to be burnt
     * @notice This function will burn YD when called, only call if you are sure
     */
    function burnYD(uint256 amountYDToBurn) public shouldBeMoreThanZero(amountYDToBurn) {
        _burnYD(amountYDToBurn, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // likelihood of this happening is very very unlikely
    }

    /**
     * @param collateralAddress Address of the ERC20 collateral to liquidate from the user
     * @param user Address of the user to be liquidated. Their _healthFactor should be below MIN_HEALTH_FACTOR
     * @param debtToCover Amount of YD to be burnt to improve `user` health factor
     * @notice A user can be partially liquidated
     * @notice & @dev There is a liquidation bonus for liquidating a user
     * @dev The protocol has to be roughly 200% over-collaterized for this function to work
     * @dev A known bug would be; if the protocol were 100% or less-collaterized, we wouldn't be able to incentivize liquidators.
     *      E.g. If the price of the collateral plummetted before liquidation could take place
     */
    function liquidate(address collateralAddress, address user, uint256 debtToCover)
        external
        shouldBeMoreThanZero(debtToCover)
        nonReentrant
    {
        // check to see that `user` is in fact liquidatable
        uint256 initialUserHealthFactor = _healthFactor(user);
        if (initialUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert YeahDollarEngine__HealthFactorIsHealthy();
        }

        // We need to know the USD equivalent of debt to be covered.
        //      E.g. If covering 100 of YD, we need to know what the ETH equivalent of that debt is
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateralAddress, debtToCover);

        // We also want to give liquidators a 10% bonus
        //      i.e., They are getting 110 wETH for 100 YD
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        uint256 totalCollateralToRedeem = bonusCollateral + tokenAmountFromDebtCovered;

        _redeemCollateral(collateralAddress, totalCollateralToRedeem, user, msg.sender);
        _burnYD(debtToCover, user, msg.sender);

        uint256 finalUserHealthFactor = _healthFactor(user);
        // This condition should never hit, but no harm in being too careful
        if (finalUserHealthFactor <= initialUserHealthFactor) {
            revert YeahDollarEngine__HealthFactorNotIproved();
        }

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // >------------------------------------------------------------------------------------------------------------------------------>>>

    // >------< PUBLIC FUNCTIONS >-----<

    /**
     * @param tokenCollateralAddress Address of the token to deposit as collateral
     * @param amountCollateral Amount of collateral to deposit
     * @notice This function will deposit collateral when called
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        shouldBeMoreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;

        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        bool transferSuccessful =
            IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!transferSuccessful) {
            revert YeahDollarEngine__TransferFailed();
        }
    }

    /**
     * @param amountYDToMint Amount of YD to mint
     * @notice This function will mint YD when called
     * @notice Minting will fail if collateral value > minimum threshold
     */
    function mintYD(uint256 amountYDToMint, address tokenCollateralAddress)
        public
        shouldBeMoreThanZero(amountYDToMint)
        nonReentrant
        mintAmountMustBeLessOrEqualToUserDepositCollateral(amountYDToMint, tokenCollateralAddress)
    {
        s_YDMinted[msg.sender] += amountYDToMint;

        _revertIfHealthFactorIsBroken(msg.sender);

        bool mintSuccessful = i_yd.mint(msg.sender, amountYDToMint);

        if (!mintSuccessful) {
            revert YeahDollarEngine__MintFailed();
        }
    }

    // >------------------------------------------------------------------------------------------------------------------------------>>>

    // >------< PRIVATE FUNCTIONS >-----<

    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);

        bool redeemSuccessful = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!redeemSuccessful) {
            revert YeahDollarEngine__RedeemFailed();
        }
    }

    function _burnYD(uint256 amountYDToBurn, address onBehalfOf, address ydFrom) private {
        s_YDMinted[onBehalfOf] -= amountYDToBurn;

        bool success = i_yd.transferFrom(ydFrom, address(this), amountYDToBurn);
        if (!success) {
            revert YeahDollarEngine__TransferFailed();
        }

        i_yd.burn(amountYDToBurn);
    }

    // >------------------------------------------------------------------------------------------------------------------------------>>>

    // >------< PRIVATE & INTERNAL VIEW FUNCTIONS >-----<

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalYDMinted, uint256 collateralValueInUsd)
    {
        totalYDMinted = s_YDMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalYDMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        return _calculateHealthFactor(totalYDMinted, collateralValueInUsd);
    }

    function _getUsdValue(address token, uint256 amount) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 answer,,,) = priceFeed.latestRoundData();
        // Most USD pairs have 8 decimals, so we will assume they all do
        // We want to have everything in terms of wei, so we add 10 zeros at the end
        return ((uint256(answer) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function _calculateHealthFactor(uint256 totalYDMinted, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        if (totalYDMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalYDMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);

        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert YeahDollarEngine__HealthFactorIsBroken(userHealthFactor);
        }
    }

    // >------------------------------------------------------------------------------------------------------------------------------>>>

    // >------< PUBLIC & EXTERNAL VIEW & PURE FUNCTIONS >-----<

    function calculateHealthFactor(uint256 totalYDMinted, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalYDMinted, collateralValueInUsd);
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 answer,,,) = priceFeed.latestRoundData();
        return (usdAmountInWei * PRECISION) / (uint256(answer) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalYDMinted, uint256 collateralValueInUsd)
    {
        (totalYDMinted, collateralValueInUsd) = _getAccountInformation(user);
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += _getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amountInWei) public view returns (uint256) {
        return _getUsdValue(token, amountInWei);
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external view returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getYD() external view returns (address) {
        return address(i_yd);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    function gethealthFactor(address user) external view returns(uint256) {
        return _healthFactor(user);
    }
}
