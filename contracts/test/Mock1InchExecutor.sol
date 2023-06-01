// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract Mock1InchExecutor {
    IERC20 private immutable ESE;

    constructor(IERC20 _ESE){
        ESE = _ESE;
    }

    function execute(address msgSender, bytes memory data, uint256 amount) external payable {
        if(msg.value > 0){
            (bool success, ) = msg.sender.call{value: 10, gas: 5000}("");
            ESE.transfer(msg.sender, (msg.value - 10) * 2);
        }else{
            (IERC20 token) =  abi.decode(data, (IERC20));
            token.transfer(msg.sender, 10);
            ESE.transfer(msg.sender, (amount - 10) / 2);
        }
    }
}