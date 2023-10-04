//SPDX-License-Identifier: MIT
// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

import {MacedonianStandard} from "../src/MacedonianStandard.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "../src/libraries/OracleLib.sol";

/**
 * @author  Ilija Ristovski
 * @title   MKDEngine
 *
 * This is the contract meant to govern MacedonianStandard. It's goal is to have the tokens maintain a 1 token == 1 MKD value.
 * This stablecoin has the propertios:
 * - Exogenous Collateral
 * - Denar Pegged
 * - Algorithmically Stable
 * - Overcollateralized (Value of all collateral should not be less than the value of all MKD tokens)
 * It is similar to DAI if DAI had no governance, no fees, and was only backed by WETH and WBTC.
 * @notice This contract is the core of the Macedonian Standard stablecoin system. It handles all the logic for minting and redeeming MKD, as well as depositing & withdrawing collateral.
 * @notice This contract is very loosely based on the MakerDAO system, but is not a direct copy.
 */

contract MKDEngine is ReentrancyGuard {
    ////////////////////////////////////
    // Errors                          //
    ////////////////////////////////////
    error MKDEngine__AmountMustBeMoreThanZero();
    error MKDEngine__TokenAddressesAndPriceFeedADdressesMustBeSameLength();
    error MKDEngine__TokenIsNotAllowed();
    error MKDEngine__DepositCollateralFailed();
    error MKDEngine__BreaksHealthFactor(uint256 healthFactor);
    error MKDEngine__MintFailed();
    error MKDEngine__TransferFailed();
    error MKDEngine__HealthFactorIsOkay();
    error MKDEngine__HealthFactorDidNotImprove();

    ////////////////////////////////////
    // Types                          //
    ////////////////////////////////////
    using OracleLib for AggregatorV3Interface;

    ////////////////////////////////////
    // State Variables                  //
    ////////////////////////////////////
    MacedonianStandard private immutable i_MKD;

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant DOLLAR_TO_MKD_RATIO = 55;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;

    mapping(address token => address priceFeed) private s_priceFeeds; //tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountMKDMinted) private s_MKDMinted;
    address[] private s_collateralTokens;

    ////////////////////////////////////
    // Events                         //
    ////////////////////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    ////////////////////////////////////
    // Modifiers                      //
    ////////////////////////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert MKDEngine__AmountMustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address tokenAddress) {
        if (s_priceFeeds[tokenAddress] == address(0)) {
            revert MKDEngine__TokenIsNotAllowed();
        }
        _;
    }

    ////////////////////////////////////
    // Functions                        //
    ////////////////////////////////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address mkdAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert MKDEngine__TokenAddressesAndPriceFeedADdressesMustBeSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_MKD = MacedonianStandard(mkdAddress);
    }

    ////////////////////////////////////
    // External Functions               //
    ////////////////////////////////////

    /**
     * @notice follows CEI
     * @param amountMKDToMint The amount of decentralized stablecoin to mint
     * @notice they must have more collateral value than the minimum threshold
     */
    function mintMKD(uint256 amountMKDToMint) public moreThanZero(amountMKDToMint) nonReentrant {
        s_MKDMinted[msg.sender] += amountMKDToMint;
        //if they minted too much ($150 MKD, $100 ETH)
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_MKD.mint(msg.sender, amountMKDToMint);
        if (!minted) {
            revert MKDEngine__MintFailed();
        }
    }

    /*
     * @notice Follows CEI
     * @param tokenCollateralAddress The address of the token to be deposited as collateral
     * @param amountCollateral The amount of collateral to be deposited
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert MKDEngine__DepositCollateralFailed();
        }
    }
    /**
     * @notice Follows CEI
     * @param tokenCollateralAddress The address of the ERC20 token to be deposited as collateral
     * @param amountCollateral The amount of collateral to be deposited
     * @param amountMKDToMint The amount of decentralized stablecoin to mint
     * @notice they must have more collateral value than the minimum threshold
     */

    function depositCollateralAndMintMKD(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountMKDToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintMKD(amountMKDToMint);
    }

    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @param tokenCollateralAddress The collateral address to redeem
     * @param amountCollateral The amount of collateral to redeem
     * @param amountMKDToBurn The amount of MKD stable coin to burn
     * This function burns MKD and redeems underlyning collateral in one transaction
     */
    function redeemCollateralForMKD(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountMKDToBurn)
        external
    {
        burnMKD(amountMKDToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    function burnMKD(uint256 amount) public moreThanZero(amount) {
        _burnMKD(msg.sender, msg.sender, amount);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @param collateral The ERC20 collateral address to liquidate from the user
     * @param user The user to liquidate / has broken the health factor
     * @param debtToCover The amount of MKD stablecoin to cover
     * @notice You can partially liquidate a user
     * @notice You will get a liquidation bonus for taking the users funds
     * @notice This function working assumes the protocol will be roughly 200% overcollateralized in order for this to work
     * @notice A known bug would be if the protocol were 100% or less collateralized, then we wouldn't be able to incentive the liquidators
     * For example, if the price of the collateral plummeted before anyone could be liquidated.
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert MKDEngine__HealthFactorIsOkay();
        }
        //Bad User: 14 000 denars worth of ETH, 10 000 denars worth of MKD
        //debtToCover = 10 000
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromDenar(collateral, debtToCover);
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);
        _burnMKD(user, msg.sender, debtToCover);
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert MKDEngine__HealthFactorDidNotImprove();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactior() external view {}

    ////////////////////////////////////
    // Private & Internal View Functions //
    ////////////////////////////////////

    /**
     * @dev Low-level internal function, do not call unless the function calling it is checking for health factors being broken
     */
    function _burnMKD(address onBehalfOf, address mkdFrom, uint256 amountMKDToBurn) private {
        s_MKDMinted[onBehalfOf] -= amountMKDToBurn;
        bool success = i_MKD.transferFrom(mkdFrom, address(this), amountMKDToBurn);
        if (!success) {
            revert MKDEngine__TransferFailed();
        }
        i_MKD.burn(amountMKDToBurn);
    }

    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert MKDEngine__TransferFailed();
        }
    }

    function _getUserAccountInformation(address userAddress)
        private
        view
        returns (uint256 totalMKDMinted, uint256 collateralValueInMKD)
    {
        totalMKDMinted = s_MKDMinted[userAddress];
        collateralValueInMKD = getAccountCollateralValue(userAddress);
    }

    /**
     * Returns how close to liquadation a user is
     * If a user goes below 1, then they can get liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalMKDMinted, uint256 collateralValueInMKD) = _getUserAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInMKD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        //E.g. 55 000 DEN ($1000) ETH / 100 DSC
        // 55000 * 50 = 1100 / 100 = (11 / 100) > 1

        return (collateralAdjustedForThreshold * PRECISION) / totalMKDMinted;
    }

    function _calculateHealthFactor(uint256 totalMKDMinted, uint256 collateralValueInDenar)
        internal
        pure
        returns (uint256)
    {
        if (totalMKDMinted == 0) {
            return type(uint256).max;
        }
        uint256 collateralAdjustedForThreshold =
            (collateralValueInDenar * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * 1e18) / totalMKDMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert MKDEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    ////////////////////////////////////
    // Public & External View Functions //
    ////////////////////////////////////

    function calculateHealthFactor(uint256 totalMKDMinted, uint256 collateralValueInDenar)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalMKDMinted, collateralValueInDenar);
    }

    /////////////////////////////////
    //////Get Functions//////////////
    /////////////////////////////////

    function getTokenAmountFromDenar(address token, uint256 denarAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        // (denar 60 000e18 * 1e18) / (2000e8 * 55 * 1e10)

        return (denarAmountInWei * PRECISION) / (uint256(price) * DOLLAR_TO_MKD_RATIO * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInMKD) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInMKD += getMkdValue(token, amount);
        }
        return totalCollateralValueInMKD;
    }

    function getMkdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        uint256 usdPrice = uint256(price); //
        uint256 mkdPrice = (usdPrice * DOLLAR_TO_MKD_RATIO * ADDITIONAL_FEED_PRECISION);
        return ((mkdPrice * amount) / PRECISION);
    }

    function getUserAccountInformation(address user)
        external
        view
        returns (uint256 totalMKDMinted, uint256 collateralValueInMKD)
    {
        (totalMKDMinted, collateralValueInMKD) = _getUserAccountInformation(user);
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
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

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getMKD() external view returns (address) {
        return address(i_MKD);
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }
}
