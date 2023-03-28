// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract ESE is ERC20 {
    constructor(uint256 amount) ERC20("eesee", "ESE") {
        //TODO: premint + vesting + IDO - нужно обсуждение с заказчиком
        //TODO: remove this
        _mint(msg.sender, amount);
    }
}