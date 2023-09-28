//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {MKDEngine} from "../../src/MKDEngine.sol";
import {MacedonianStandard} from "../../src/MacedonianStandard.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    MKDEngine mkdEngine;
    MacedonianStandard mkd;
    ERC20Mock wEth;
    ERC20Mock wBtc;

    uint256 public timesMintCalled;
    address[] public usersWithCollateralDeposited;
    MockV3Aggregator public ethPriceFeed;

    uint256 constant MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(MKDEngine _mkdEngine, MacedonianStandard _mkd) {
        mkdEngine = _mkdEngine;
        mkd = _mkd;
        address[] memory collateralTokens = mkdEngine.getCollateralTokens();
        wEth = ERC20Mock(collateralTokens[0]);
        wBtc = ERC20Mock(collateralTokens[1]);

        ethPriceFeed = MockV3Aggregator(mkdEngine.getCollateralTokenPriceFeed(address(wEth)));
    }

    function mintMkd(uint256 amount, uint256 addressSeed) public {
        if (usersWithCollateralDeposited.length == 0) {
            return;
        }

        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
        (uint256 totalMKDMinted, uint256 collateralValueInMKD) = mkdEngine.getUserAccountInformation(sender);
        int256 maxMkdToMint = (int256(collateralValueInMKD) / 2) - int256(totalMKDMinted);
        if (maxMkdToMint < 0) {
            return;
        }
        amount = bound(amount, 0, uint256(maxMkdToMint));
        if (amount == 0) {
            return;
        }
        vm.startPrank(sender);
        mkdEngine.mintMKD(amount);
        vm.stopPrank();
        timesMintCalled++;
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(mkdEngine), amountCollateral);
        mkdEngine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = mkdEngine.getCollateralBalanceOfUser(address(collateral), msg.sender);
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) {
            return;
        }
        mkdEngine.redeemCollateral(address(collateral), amountCollateral);
    }

    //Come back to this (breaks)
    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethPriceFeed.updateAnswer(newPriceInt);
    // }

    //Helper functions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return wEth;
        }
        return wBtc;
    }
}
