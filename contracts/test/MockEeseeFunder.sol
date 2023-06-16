// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract MockEeseeFunder {
    error TransferNotSuccessful();
    function fund(address to) external payable {
        (bool success, ) = to.call{value: msg.value }("");
        if(!success) revert TransferNotSuccessful();
    }
}