// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

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

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @author  Ilija Ristovski
 * @title   Decentralized Stable Coin linked to the Macedonian Denar
 * @dev     This is a decentralized stable coin that is pegged to the Macedonian Denar
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Relative Stability: Pegged to the Macedonian Denar
 *
 * This is the contract meant to be governed by MKDEngine.
 *    This contract is just the ERC20 implementation of our stablecoin system.
 */

contract MacedonianStandard is ERC20Burnable, Ownable {
    /**
     * Errors
     */
    error MacedonianStandard__MustBeMoreThanZero();
    error MacedonianStandard__BurnAmountExceedsBalance();
    error MacedonianStandard__NotZeroAddress();

    constructor() ERC20("Macedonian Standard", "MKD") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert MacedonianStandard__MustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert MacedonianStandard__BurnAmountExceedsBalance();
        }

        super.burn(_amount); //Use the burn function from the parent class (ERC20Burnable)
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert MacedonianStandard__NotZeroAddress();
        }

        if (_amount <= 0) {
            revert MacedonianStandard__MustBeMoreThanZero();
        }

        _mint(_to, _amount);
        return true;
    }
}
