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
    /**
     * Errors
     */
    error MKDEngine__AmountMustBeMoreThanZero();
    error MKDEngine__TokenAddressesAndPriceFeedADdressesMustBeSameLength();
    error MKDEngine__TokenIsNotAllowed();
    error MKDEngine__DepositCollateralFailed();

    /**
     * State Variables
     */
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant DOLLAR_TO_MKD_RATIO = 55;
    mapping(address token => address priceFeed) private s_priceFeeds; //tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountMKDMinted) private s_MKDMinted;
    address[] private s_collateralTokens;

    MacedonianStandard private immutable i_MKD;

    /**
     * Events
     */
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

    /**
     * Modifiers
     */
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

    /**
     * Functions
     */

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

    /**
     * External Functions
     */
    function depositCollateralAndMintMKD() external {}

    /*
     * @notice Follows CEI
     * @param tokenCollateralAddress The address of the token to be deposited as collateral
     * @param amountCollateral The amount of collateral to be deposited
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
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

    function redeemCollateral() external {}

    /**
     * @notice follows CEI
     * @param amountMKDToMint The amount of decentralized stablecoin to mint
     * @notice they must have more collateral value than the minimum threshold
     */
    function mintMKD(uint256 amountMKDToMint) external moreThanZero(amountMKDToMint) nonReentrant {
        s_MKDMinted[msg.sender] += amountMKDToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function redeemCollateralForMKD() external {}

    function burnMKD() external {}

    function liquadate() external {}

    function getHealthFactior() external view {}

    /**
     * Private & Internal View Functions
     */

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
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {}

    /**
     * Public & External View Functions
     */
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
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION) * DOLLAR_TO_MKD_RATIO;
    }
}
