// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../interfaces/IESECrowdsale.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Crowdsale
 * @dev Functionality is adapted from OpenZeppelin's Crowdsale contracts.
 */
contract ESECrowdsale is IESECrowdsale, Ownable {
    using SafeERC20 for IERC20;

    ///@dev The token being sold
    IERC20 public immutable ESE;
    ///@dev The token being bought
    IERC20 public immutable token;
    ///@dev Address where funds are collected
    address public wallet;

    /**
        @dev How many token units a buyer gets per wei.
        The rate is the conversion between wei and the smallest and indivisible token unit.
        So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
        1 wei will give you 1 unit, or 0.001 TOK.
    */
    uint256 public immutable rate;

    ///@dev Minimum/Maximum amounts of tokens that can be bought by a single account.(in ESE)
    uint256 public immutable minSellAmount;
    uint256 public immutable maxSellAmount;
    ///@dev Tokens bought by address.
    mapping(address => uint256) private tokensSoldToAddress;

    ///@dev The time when this crowdsale opens/closes.
    uint256 public immutable openingTime;
    uint256 public closingTime;

    ///@dev Whitelist Merkle Root. If == bytes32(0) everyone is whitelisted.
    bytes32 public immutable whitelistMerkleRoot;//TODO: add multiple phases in the future

    constructor (
        uint256 _rate, 
        address _wallet, 
        IERC20 _ESE, 
        IERC20 _token,
        uint256 _minSellAmount,
        uint256 _maxSellAmount,
        uint256 _openingTime, 
        uint256 _closingTime,
        bytes32 _whitelistMerkleRoot
    ) {
        if (_rate == 0) revert InvalidRate();
        if (_wallet == address(0)) revert InvalidWallet();
        if (address(_ESE) == address(0)) revert InvalidESE();
        if (address(_token) == address(0)) revert InvalidToken();
        if (_maxSellAmount == 0) revert InvalidMaxSellAmount();
        if (_minSellAmount > _maxSellAmount) revert MinSellAmountTooHigh(_maxSellAmount);
        if (_openingTime < block.timestamp) revert InvalidOpeningTime();
        if (_closingTime <= _openingTime) revert InvalidClosingTime();
        
        rate = _rate;
        wallet = _wallet;
        ESE = _ESE;
        token = _token;
        minSellAmount = _minSellAmount;
        maxSellAmount = _maxSellAmount;
        openingTime = _openingTime;
        closingTime = _closingTime;
        whitelistMerkleRoot = _whitelistMerkleRoot;
    }

    /**
     * @return bool - {true} if the crowdsale is open, {false} otherwise.
     */
    function isOpen() public view returns (bool) {
        return block.timestamp >= openingTime && block.timestamp <= closingTime;
    }

    /**
     * @dev Checks whether the period in which the crowdsale is open has already elapsed.
     * @return bool - Whether crowdsale period has elapsed
     */
    function hasClosed() public view returns (bool) {
        return block.timestamp > closingTime;
    }

    /**
     * @dev Verifies that {_address} is whitelisted. If no {whitelistMerkleRoot} provided, everyone is whitelisted.
     * @param _address - Address to verify claim for.
     * @param merkleProof - Merkle Proof to verify.

     * @return bool - Is whitelisted.
     */
    function isWhitelisted(address _address, bytes32[] memory merkleProof) public view returns (bool) {
        if(whitelistMerkleRoot == bytes32(0)){
            return true;
        }
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_address))));
        return MerkleProof.verify(merkleProof, whitelistMerkleRoot, leaf);
    }

    /**
     * @dev Buy ESE tokens from this contract. Forwards collected funds to {wallet}.
     * @param beneficiary Recipient of the token purchase.
     * @param amount Amount of ESE to buy.
     * @param merkleProof Merkle Proof required for this purchase.
     */
    function buyESE(address beneficiary, uint256 amount, bytes32[] memory merkleProof) external returns(uint256 tokensSpent) {
        if(!isOpen()) revert NotOpen();
        if(!isWhitelisted(msg.sender, merkleProof)) revert NotWhitelisted();
        if(beneficiary == address(0)) revert InvalidBeneficiary();

        tokensSoldToAddress[msg.sender] += amount;
        if(tokensSoldToAddress[msg.sender] < minSellAmount) revert SellAmountTooLow(minSellAmount);
        if(tokensSoldToAddress[msg.sender] > maxSellAmount) revert SellAmountTooHigh(maxSellAmount);

        tokensSpent = amount / rate;
        ESE.safeTransfer(beneficiary, amount);
        token.safeTransferFrom(msg.sender, wallet, tokensSpent);

        emit TokensPurchased(msg.sender, beneficiary, tokensSpent, amount);
    }

    // =============== Admin Functions ================

    /**
     * @dev Changes wallet. Emits {ChangeWallet} event.
     * @param _wallet - New wallet.
     * Note: This function can only be called by owner.
     */
    function changeWallet(address _wallet) external onlyOwner {
        if(_wallet == address(0)) revert InvalidWallet();
        emit ChangeWallet(wallet, _wallet);
        wallet = _wallet;
    }

    /**
     * @dev Extend crowdsale.
     * @param _closingTime Crowdsale closing time
     */
    function extendTime(uint256 _closingTime) external onlyOwner{
        if(hasClosed()) revert AlreadyClosed(closingTime);
        if(_closingTime <= closingTime) revert InvalidClosingTime();

        emit TimedCrowdsaleExtended(closingTime, _closingTime);
        closingTime = _closingTime;
    }
}
