//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployMKD} from "../../script/DeployMKD.s.sol";
import {MacedonianStandard} from "../../src/MacedonianStandard.sol";
import {MKDEngine} from "../../src/MKDEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";

contract MKDEngineTest is Test {
    DeployMKD deployer;
    MacedonianStandard public macedonianStandard;
    MKDEngine public mkdEngine;
    HelperConfig config;

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address wEth;
    address wBtc;
    uint256 public deployerKey;

    uint256 amountCollateral = 10 ether;
    uint256 amountTOMint = 100 ether;
    address public user = address(1);

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    //Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    function setUp() public {
        deployer = new DeployMKD();
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

    //TO-DO: Return to this
    function testGetTokenAmountFromDenar() public {
        uint256 mkdAmount = 110000 ether;
        uint256 expectedWeth = 0.5 ether;
        //( 2000 USD per ETH * 55 MKD/USD) / 110000e18 = 5500 / 110 000 = 0.05 ether
        uint256 actualWeth = mkdEngine.getTokenAmountFromDenar(wEth, mkdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    //////////////////////////////
    /// Deposit Collateral Tests /
    //////////////////////////////

    function testRevertsIfTransferFromFails() public {
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransferFrom mockMKD = new MockFailedTransferFrom();
        tokenAddresses = [address(mockMKD)];
        priceFeedAddresses = [ethUsdPriceFeed];
        vm.prank(owner);
        MKDEngine mockMKDEngine = new MKDEngine(tokenAddresses, priceFeedAddresses, address(mockMKD));

        mockMKD.mint(user, amountCollateral);

        vm.prank(owner);
        mockMKD.transferOwnership(address(mockMKDEngine));
        //Arrange - User
        vm.startPrank(user);
        ERC20Mock(address(mockMKD)).approve(address(mockMKDEngine), amountCollateral);
        //Act / Assert
        vm.expectRevert(MKDEngine.MKDEngine__TransferFailed.selector);
        mockMKDEngine.depositCollateral(address(mockMKD), amountCollateral);
        vm.stopPrank();
    }

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

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalMKDMinted, uint256 collateralValueInMKD) = mkdEngine.getUserAccountInformation(user);
        uint256 expectedTotalMKDMinted = 0;
        //uint256 expectedDepositAmount = mkdEngine.getTokenAmountFromDenar(wEth, collateralValueInMKD);
        //55000.0000000000000000
        //10.000000000000000000
        assertEq(expectedTotalMKDMinted, totalMKDMinted);
        //assertEq(expectedDepositAmount, amountCollateral); //TO-DO: Come back to this
    }
}
