// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract MockRoyaltyEngine {
    function getRoyalty(address tokenAddress, uint256 tokenId, uint256 value)
        public
        view
        returns (address payable[] memory, uint256[] memory)
    {
        address payable[] memory recipients = new address payable[](1);
        uint256[] memory amounts = new uint256[](1);
        (address royaltyReciever, uint256 royaltyAmount) = ERC2981(tokenAddress).royaltyInfo(tokenId, value);
        recipients[0] = payable(royaltyReciever);
        amounts[0] = royaltyAmount;
        return (recipients, amounts);
    }
}