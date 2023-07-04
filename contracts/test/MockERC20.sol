// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MockERC20 is ERC20 {
    constructor(uint256 amount) ERC20("erc", "ERC20") {
        _mint(msg.sender, amount);
    }
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    function transferAndCall(address to, uint256 amount, bytes calldata) external returns (bool success){
        _transfer(msg.sender, to, amount);
    }
}