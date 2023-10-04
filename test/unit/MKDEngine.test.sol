//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployMKD} from "../../script/DeployMKD.s.sol";
import {MacedonianStandard} from "../../src/MacedonianStandard.sol";
import {MKDEngine} from "../../src/MKDEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {MockFailedMintMKD} from "../mocks/MockFailedMintMKD.sol";
import {MockFailedTransfer} from "../mocks/MockFailedTransfer.sol";

contract MKDEngineTest is Test {
    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount);

    MacedonianStandard public macedonianStandard;
    MKDEngine public mkdEngine;
    HelperConfig config;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public wEth;
    address public wBtc;
    uint256 public deployerKey;

    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;
    address public user = address(1);

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    //Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    function setUp() public {
        DeployMKD deployer = new DeployMKD();
        (macedonianStandard, mkdEngine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, wEth, wBtc, deployerKey) = config.activeNetworkConfig();

        if (block.chainid == 31337) {
            vm.deal(user, STARTING_USER_BALANCE);
        }

        ERC20Mock(wEth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(wBtc).mint(user, STARTING_USER_BALANCE);
    }

    //////////////////////
    /// Constructor Tests/
    //////////////////////

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(wEth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(MKDEngine.MKDEngine__TokenAddressesAndPriceFeedADdressesMustBeSameLength.selector);
        new MKDEngine(tokenAddresses, priceFeedAddresses, address(mkdEngine));
    }

    ////////////////////
    /// Price Tests ////
    ////////////////////

    function testGetMkdValue() public {
        uint256 ethAmount = 1e18;
        uint256 expectedMkdValue = 110000e18; // 1e18 * (2000 USD per ETH * 55 MKD/USD) = 110000e18
        uint256 actualMkdValue = mkdEngine.getMkdValue(wEth, ethAmount);
        assertEq(expectedMkdValue, actualMkdValue);
    }

    function testGetTokenAmountFromDenar() public {
        uint256 usdAmount = 2000 ether;
        uint256 denarAmount = usdAmount * 55;
        uint256 expectedWeth = 1 ether;
        uint256 actualWeth = mkdEngine.getTokenAmountFromDenar(wEth, denarAmount);
        assertEq(expectedWeth, actualWeth);
    }

    //////////////////////////////
    /// Deposit Collateral Tests /
    //////////////////////////////

    //TO-DO: Fix this test
    // function testRevertsIfTransferFromFails() public {
    //     address owner = msg.sender;
    //     vm.prank(owner);
    //     MockFailedTransferFrom mockMKD = new MockFailedTransferFrom();
    //     tokenAddresses = [address(mockMKD)];
    //     priceFeedAddresses = [ethUsdPriceFeed];
    //     vm.prank(owner);
    //     MKDEngine mockMKDEngine = new MKDEngine(tokenAddresses, priceFeedAddresses, address(mockMKD));

    //     mockMKD.mint(user, amountCollateral);

    //     vm.prank(owner);
    //     mockMKD.transferOwnership(address(mockMKDEngine));
    //     //Arrange - User
    //     vm.startPrank(user);
    //     ERC20Mock(address(mockMKD)).approve(address(mockMKDEngine), amountCollateral);
    //     //Act / Assert
    //     vm.expectRevert(MKDEngine.MKDEngine__TransferFailed.selector);
    //     mockMKDEngine.depositCollateral(address(mockMKD), amountCollateral);
    //     vm.stopPrank();
    // }

    function testRevertIfCollateralZero() public {
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(mkdEngine), amountCollateral);
        vm.expectRevert(MKDEngine.MKDEngine__AmountMustBeMoreThanZero.selector);
        mkdEngine.depositCollateral(wEth, 0);
        vm.stopPrank();
    }

    function testRevertWithUnapprovedColalteral() public {
        ERC20Mock ranToken = new ERC20Mock();
        vm.startPrank(user);
        vm.expectRevert(MKDEngine.MKDEngine__TokenIsNotAllowed.selector);
        mkdEngine.depositCollateral(address(ranToken), amountCollateral);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(mkdEngine), amountCollateral);
        mkdEngine.depositCollateral(wEth, amountCollateral);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralWithoutMinting() public depositedCollateral {
        uint256 userBalance = macedonianStandard.balanceOf(user);
        assertEq(userBalance, 0);
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalMKDMinted, uint256 collateralValueInMKD) = mkdEngine.getUserAccountInformation(user);
        uint256 expectedTotalMKDMinted = 0;
        uint256 expectedDepositAmount = mkdEngine.getTokenAmountFromDenar(wEth, collateralValueInMKD);
        assertEq(expectedTotalMKDMinted, totalMKDMinted);
        assertEq(expectedDepositAmount, amountCollateral);
    }

    ///////////////////////////////////////////
    // Deposit Collateral and Mint MKD Tests //
    ///////////////////////////////////////////

    function testRevertsIfMintedMKDBreakHealthFactor() public {
        //TO-DO: come back to this test
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        amountToMint =
            (amountCollateral * (uint256(price) * mkdEngine.getAdditionalFeedPrecision())) / mkdEngine.getPrecision();
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(mkdEngine), amountCollateral);

        uint256 expectedHealthFactor =
            mkdEngine.calculateHealthFactor(amountToMint, mkdEngine.getMkdValue(wEth, amountCollateral));
        vm.expectRevert(abi.encodeWithSelector(MKDEngine.MKDEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        mkdEngine.depositCollateralAndMintMKD(wEth, amountCollateral, amountToMint);
        vm.stopPrank();
    }

    modifier depositedCollateralAndMintedMKD() {
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(mkdEngine), amountCollateral);
        mkdEngine.depositCollateralAndMintMKD(wEth, amountCollateral, amountToMint);
        vm.stopPrank();
        _;
    }

    function testCanMintWithDepositedCollateral() public depositedCollateralAndMintedMKD {
        uint256 userBalance = macedonianStandard.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }

    ///////////////////////////////////
    // Mint MKD Tests //
    ///////////////////////////////////

    function testRevertsIfMintFails() public {
        //Arrange
        MockFailedMintMKD mockMKD = new MockFailedMintMKD();
        tokenAddresses = [wEth];
        priceFeedAddresses = [ethUsdPriceFeed];
        address owner = msg.sender;

        vm.prank(owner);
        MKDEngine mockMKDEngine = new MKDEngine(tokenAddresses, priceFeedAddresses, address(mockMKD));
        mockMKD.transferOwnership(address(mockMKDEngine));
        //Arrange - User
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(mockMKDEngine), amountCollateral);

        vm.expectRevert(MKDEngine.MKDEngine__MintFailed.selector);
        mockMKDEngine.depositCollateralAndMintMKD(wEth, amountCollateral, amountToMint);
        vm.stopPrank();
    }

    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(mkdEngine), amountCollateral);
        mkdEngine.depositCollateralAndMintMKD(wEth, amountCollateral, amountToMint);
        vm.expectRevert(MKDEngine.MKDEngine__AmountMustBeMoreThanZero.selector);
        mkdEngine.mintMKD(0);
        vm.stopPrank();
    }

    //TO-DO: Fix this test
    function testRevertsIfMintAmountBreaksHealthFactor() public depositedCollateral {
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        amountToMint =
            (amountCollateral * (uint256(price) * mkdEngine.getAdditionalFeedPrecision())) / mkdEngine.getPrecision();
        vm.startPrank(user);
        uint256 expectedHealthFactor =
            mkdEngine.calculateHealthFactor(amountToMint, mkdEngine.getMkdValue(wEth, amountCollateral));
        vm.expectRevert(abi.encodeWithSelector(MKDEngine.MKDEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        mkdEngine.mintMKD(amountToMint);
        vm.stopPrank();
    }

    function testCanMintMKD() public depositedCollateral {
        vm.prank(user);
        mkdEngine.mintMKD(amountToMint);
        uint256 userBalance = macedonianStandard.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }

    ///////////////////////////////////
    ////////Burn MKD Tests/////////////
    ///////////////////////////////////

    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(mkdEngine), amountCollateral);
        mkdEngine.depositCollateralAndMintMKD(wEth, amountCollateral, amountToMint);
        vm.expectRevert(MKDEngine.MKDEngine__AmountMustBeMoreThanZero.selector);
        mkdEngine.burnMKD(0);
        vm.stopPrank();
    }

    function testCantBurnMoreThanUserHas() public {
        vm.prank(user);
        vm.expectRevert();
        mkdEngine.burnMKD(1);
    }

    //TO-DO: fix this
    function testCanBurnMKD() public depositedCollateralAndMintedMKD {
        vm.startPrank(user);
        macedonianStandard.approve(address(mkdEngine), amountToMint);
        mkdEngine.burnMKD(amountToMint);
        vm.stopPrank();

        uint256 userBalance = macedonianStandard.balanceOf(user);
        assertEq(userBalance, 0);
    }

    ///////////////////////////////////
    ////////Redeem Collateral Tests////
    ///////////////////////////////////
    function testRevertsIfTransferFails() public {
        // Arrange - Setup
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransfer mockMacedonianStandard = new MockFailedTransfer();
        tokenAddresses = [address(mockMacedonianStandard)];
        priceFeedAddresses = [ethUsdPriceFeed];
        vm.prank(owner);
        MKDEngine mockMKDEngine = new MKDEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(mockMacedonianStandard)
        );
        mockMacedonianStandard.mint(user, amountCollateral);

        vm.prank(owner);
        mockMacedonianStandard.transferOwnership(address(mockMKDEngine));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(address(mockMacedonianStandard)).approve(address(mockMKDEngine), amountCollateral);
        // Act / Assert
        mockMKDEngine.depositCollateral(address(mockMacedonianStandard), amountCollateral);
        vm.expectRevert(MKDEngine.MKDEngine__TransferFailed.selector);
        mockMKDEngine.redeemCollateral(address(mockMacedonianStandard), amountCollateral);
        vm.stopPrank();
    }

    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(wEth).approve(address(mkdEngine), amountCollateral);
        mkdEngine.depositCollateralAndMintMKD(wEth, amountCollateral, amountToMint);
        vm.expectRevert(MKDEngine.MKDEngine__AmountMustBeMoreThanZero.selector);
        mkdEngine.redeemCollateral(wEth, 0);
        vm.stopPrank();
    }

    //TO-DO: Fix this (modulo by 0)
    function testCanRedeemCollateral() public depositedCollateral {
        vm.startPrank(user);
        mkdEngine.redeemCollateral(wEth, amountCollateral);
        uint256 userBalance = ERC20Mock(wEth).balanceOf(user);
        assertEq(userBalance, amountCollateral);
        vm.stopPrank();
    }

    //TO-DO: Fix this expected emit but no emit
    function testEmitCollateralRedeemedWithCorrectArgs() public depositedCollateral {
        vm.expectEmit(true, true, true, true, address(mkdEngine));
        emit CollateralRedeemed(user, user, wEth, amountCollateral);
        vm.startPrank(user);
        mkdEngine.redeemCollateral(wEth, amountCollateral);
        vm.stopPrank();
    }

    ///////////////////////////////////
    // View & Pure Function Tests //
    //////////////////////////////////

    function testGetCollateralTokenPriceFeed() public {
        address priceFeed = mkdEngine.getCollateralTokenPriceFeed(wEth);
        assertEq(priceFeed, ethUsdPriceFeed);
    }

    function testGetCollateralTokens() public {
        address[] memory collateralTokens = mkdEngine.getCollateralTokens();
        assertEq(collateralTokens[0], wEth);
    }

    function testGetMinHealthFactor() public {
        uint256 minHealthFactor = mkdEngine.getMinHealthFactor();
        assertEq(minHealthFactor, MIN_HEALTH_FACTOR);
    }

    function testGetLiquidationThreshold() public {
        uint256 liquidationThreshold = mkdEngine.getLiquidationThreshold();
        assertEq(liquidationThreshold, LIQUIDATION_THRESHOLD);
    }

    function testGetAccountCollateralValueFromInformation() public depositedCollateral {
        (, uint256 collateralValue) = mkdEngine.getUserAccountInformation(user);
        uint256 expectedCollateralValue = mkdEngine.getMkdValue(wEth, amountCollateral);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetCollateralBalanceOfUser() public depositedCollateral {
        uint256 collateralBalance = mkdEngine.getCollateralBalanceOfUser(user, wEth);
        assertEq(collateralBalance, amountCollateral);
    }

    function testGetAccountCollateralValue() public depositedCollateral {
        uint256 collateralValue = mkdEngine.getAccountCollateralValue(user);
        uint256 expectedCollateralValue = mkdEngine.getMkdValue(wEth, amountCollateral);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetMKD() public {
        address mkdAddress = mkdEngine.getMKD();
        assertEq(mkdAddress, address(macedonianStandard));
    }

    function testLiquidationPrecision() public {
        uint256 expectedLiquidationPrecision = 100;
        uint256 actualLiquidationPrecision = mkdEngine.getLiquidationPrecision();
        assertEq(expectedLiquidationPrecision, actualLiquidationPrecision);
    }
}
