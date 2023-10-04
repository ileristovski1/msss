// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {MacedonianStandard} from "../../src/MacedonianStandard.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract MacedonianStandardTest is StdCheats, Test {
    MacedonianStandard macedonianStandard;

    function setUp() public {
        macedonianStandard = new MacedonianStandard();
    }

    function testMustMintMoreThanZero() public {
        vm.prank(macedonianStandard.owner());
        vm.expectRevert();
        macedonianStandard.mint(address(this), 0);
    }

    function testMustBurnMoreThanZero() public {
        vm.startPrank(macedonianStandard.owner());
        macedonianStandard.mint(address(this), 100);
        vm.expectRevert();
        macedonianStandard.burn(0);
        vm.stopPrank();
    }

    function testCantBurnMoreThanYouHave() public {
        vm.startPrank(macedonianStandard.owner());
        macedonianStandard.mint(address(this), 100);
        vm.expectRevert();
        macedonianStandard.burn(101);
        vm.stopPrank();
    }

    function testCantMintToZeroAddress() public {
        vm.startPrank(macedonianStandard.owner());
        vm.expectRevert();
        macedonianStandard.mint(address(0), 100);
        vm.stopPrank();
    }
}
