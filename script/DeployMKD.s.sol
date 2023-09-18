//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MacedonianStandard} from "../src/MacedonianStandard.sol";
import {MKDEngine} from "../src/MKDEngine.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployMKD is Script {
    MacedonianStandard macedonianStandard;
    MKDEngine mkdEngine;
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (MacedonianStandard, MKDEngine, HelperConfig) {
        HelperConfig config = new HelperConfig();

        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            config.activeNetworkConfig();
        vm.startBroadcast(deployerKey);

        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        macedonianStandard = new MacedonianStandard();
        mkdEngine = new MKDEngine(tokenAddresses, priceFeedAddresses, address(macedonianStandard));

        macedonianStandard.transferOwnership(address(mkdEngine));
        vm.stopBroadcast();

        return (macedonianStandard, mkdEngine, config);
    }
}
