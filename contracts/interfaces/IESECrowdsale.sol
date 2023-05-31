// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IESECrowdsale {
    event TokensPurchased(
        address indexed purchaser, 
        address indexed beneficiary, 
        uint256 value, 
        uint256 amount
    );
    event ChangeWallet(
        address indexed previousWallet, 
        address indexed newWallet
    );
    event TimedCrowdsaleExtended(
        uint256 previousClosingTime, 
        uint256 newClosingTime
    );

    error AlreadyClosed(uint256 closingTime);
    error NotOpen();
    error NotWhitelisted();
    
    error InvalidBeneficiary();
    error InvalidRate();
    error InvalidWallet();
    error InvalidESE();
    error InvalidOpeningTime();
    error InvalidClosingTime();
    error InvalidToken();
    error InvalidMaxSellAmount();

    error SellAmountTooHigh(uint256 maxSellAmount);
    error SellAmountTooLow(uint256 minSellAmount);
    error MinSellAmountTooHigh(uint256 cap);

    function ESE() external view returns (IERC20);
    function token() external view returns (IERC20);
    function wallet() external view returns (address);
    function rate() external view returns (uint256);
    function minSellAmount() external view returns (uint256);
    function maxSellAmount() external view returns (uint256);
    function openingTime() external view returns (uint256);
    function whitelistMerkleRoot() external view returns (bytes32);

    function isOpen() external view returns (bool);
    function isWhitelisted(address _address, bytes32[] memory merkleProof) external view returns (bool);

    function buyESE(address beneficiary, uint256 amount, bytes32[] memory merkleProof) external returns(uint256 tokensBought);
    function changeWallet(address _wallet) external;
}