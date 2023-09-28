//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

//This file has our invariants (properties)

//1. The total amount of MKD in circulation is equal to the total amount of collateral in the system

//2. Getter view functions should never revert

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployMKD} from "../../script/DeployMKD.s.sol";
import {MKDEngine} from "../../src/MKDEngine.sol";
import {MacedonianStandard} from "../../src/MacedonianStandard.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.test.sol";

contract InvariantTest is StdInvariant, Test {
    DeployMKD deployer;
    MKDEngine mkdE;
    MacedonianStandard mkd;
    HelperConfig config;
    address wEth;
    address wBtc;
    Handler handler;

    function setUp() external {
        deployer = new DeployMKD();
        (mkd, mkdE, config) = deployer.run();
        (,, wEth, wBtc,) = config.activeNetworkConfig();

        handler = new Handler(mkdE, mkd);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = mkd.totalSupply();
        uint256 totalWethDeposited = IERC20(wEth).balanceOf(address(mkdE));
        uint256 totalWbtcDeposited = IERC20(wBtc).balanceOf(address(mkdE));

        uint256 wEthValue = mkdE.getMkdValue(wEth, totalWethDeposited);
        uint256 wBtcValue = mkdE.getMkdValue(wBtc, totalWbtcDeposited);

        console.log("weth value", wEthValue);
        console.log("wbtc value", wBtcValue);
        console.log("total supply", totalSupply);
        console.log("times mint is called", handler.timesMintCalled());

        assert(wEthValue + wBtcValue >= totalSupply);
    }

    function invariant_gettersShouldNotRevert() public view {
        mkdE.getCollateralTokens();
    }
}
