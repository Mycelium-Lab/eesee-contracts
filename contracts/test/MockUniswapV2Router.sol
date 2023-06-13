// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockUniswapV2Router {
    IERC20 token;
    constructor(IERC20 _token){
        token = _token;
    }
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts)
    {
        token.transfer(msg.sender, msg.value);
        amounts = new uint[](2);
        amounts[0] = msg.value;
        amounts[1] = msg.value;
    }
}