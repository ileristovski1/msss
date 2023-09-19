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

    /**
     * Price Tests
     */

    function testGetMkdValue() public {
        uint256 ethAmount = 1e18;
        uint256 expectedMkdValue = 110000e18; // 1e18 * (2000 USD per ETH * 55 MKD/USD) = 110000e18
        uint256 actualMkdValue = mkdEngine.getMkdValue(wEth, ethAmount);
        assertEq(expectedMkdValue, actualMkdValue);
    }

    /**
     * Deposit Collateral Test
     */

    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(wEth).approve(address(mkdEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(MKDEngine.MKDEngine__AmountMustBeMoreThanZero.selector);
        mkdEngine.depositCollateral(wEth, 0);
        vm.stopPrank();
    }
}
