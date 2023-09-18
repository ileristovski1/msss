//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployMKD} from "../../script/DeployMKD.s.sol";
import {MacedonianStandard} from "../../src/MacedonianStandard.sol";
import {MKDEngine} from "../../src/MKDEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract MKDEngineTest is Test {
    MacedonianStandard public macedonianStandard;
    MKDEngine public mkdEngine;
    HelperConfig config;

    address ethUsdPriceFeed;
    address wEth;

    function setUp() public {
        DeployMKD deployer = new DeployMKD();
        (macedonianStandard, mkdEngine, config) = deployer.run();
        (ethUsdPriceFeed, wEth,,,) = config.activeNetworkConfig();
    }

    /**
     * Price Tests
     */

    function testGetMkdValue() public {
        uint256 ethAmount = 1e18;
        uint256 expectedMkdValue = 1650000e18; // 1e18 * (2000 USD/ETH * 55 MKD/USD)
        uint256 actualMkdValue = mkdEngine.getMkdValue(wEth, ethAmount);
        assertEq(expectedMkdValue, actualMkdValue);
    }
}
