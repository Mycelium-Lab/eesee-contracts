// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MockERC20 is ERC20 {
    constructor(uint256 amount) ERC20("erc", "ERC20") {
        _mint(msg.sender, amount);
    }
}