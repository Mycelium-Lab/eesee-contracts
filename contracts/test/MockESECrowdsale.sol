// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockESECrowdsale {
    uint256 public openingTime;

    constructor() {
        openingTime = block.timestamp;
    }

    function transfer(IERC20 token, address to, uint256 amount) external {
        token.transfer(to, amount);
    }
}