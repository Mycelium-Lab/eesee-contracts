// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract Mock1InchExecutor {
    IERC20 private immutable ESE;
    IERC20 private immutable token;

    constructor(IERC20 _ESE, IERC20 _token){
        ESE = _ESE;
        token = _token;
    }
    fallback(bytes calldata data) external payable returns (bytes memory) {
        (address msgSender, bytes memory _data, uint256 amount) =  abi.decode(data[4:], (address, bytes, uint256));
        if(msg.value > 0){
            ESE.transfer(msg.sender, msg.value * 2);
        }else{
            ESE.transfer(msg.sender, amount / 2);
        }
    }

    /*function execute(address msgSender, bytes memory data, uint256 amount) external payable {
        if(msg.value > 0){
            ESE.transfer(msg.sender, msg.value * 2);
        }else{
            token.transferFrom(msg.sender, address(this), amount);
        }
        ESE.transfer(msg.sender, amount / 2);
    }*/
}