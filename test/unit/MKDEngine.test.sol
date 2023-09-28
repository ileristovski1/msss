//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployMKD} from "../../script/DeployMKD.s.sol";
import {MacedonianStandard} from "../../src/MacedonianStandard.sol";
import {MKDEngine} from "../../src/MKDEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract MKDEngineTest is Test {
    DeployMKD deployer;
    MacedonianStandard public macedonianStandard;
    MKDEngine public mkdEngine;
    HelperConfig config;

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address wEth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployMKD();
        (macedonianStandard, mkdEngine, config) = deployer.run();
        (ethUsdPriceFeed,, wEth,,) = config.activeNetworkConfig();

        ERC20Mock(wEth).mint(USER, STARTING_ERC20_BALANCE);
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
    // function testGetTokenAmountFromDenar() public {
    //     uint256 mkdAmount = 110000 ether;
    //     uint256 expectedWeth = 0.05 ether;
    //     //( 2000 USD per ETH * 55 MKD/USD) / 110000e18 = 5500 / 110 000 = 0.05 ether
    //     uint256 actualWeth = mkdEngine.getTokenAmountFromDenar(wEth, mkdAmount);
    //     assertEq(expectedWeth, actualWeth);
    // }

    //////////////////////////////
    /// Deposit Collateral Tests /
    //////////////////////////////

    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(wEth).approve(address(mkdEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(MKDEngine.MKDEngine__AmountMustBeMoreThanZero.selector);
        mkdEngine.depositCollateral(wEth, 0);
        vm.stopPrank();
    }

    function testRevertWithUnapprovedColalteral() public {
        ERC20Mock ranToken = new ERC20Mock();
        vm.startPrank(USER);
        vm.expectRevert(MKDEngine.MKDEngine__TokenIsNotAllowed.selector);
        mkdEngine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(wEth).approve(address(mkdEngine), AMOUNT_COLLATERAL);
        mkdEngine.depositCollateral(wEth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalMKDMinted, uint256 collateralValueInMKD) = mkdEngine.getUserAccountInformation(USER);
        uint256 expectedTotalMKDMinted = 0;
        //uint256 expectedDepositAmount = mkdEngine.getTokenAmountFromDenar(wEth, collateralValueInMKD);
        //55000.0000000000000000
        //10.000000000000000000
        assertEq(expectedTotalMKDMinted, totalMKDMinted);
        //assertEq(expectedDepositAmount, AMOUNT_COLLATERAL); //TO-DO: Come back to this
    }
}
