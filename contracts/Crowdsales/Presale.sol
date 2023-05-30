pragma solidity 0.8.17;

import './Crowdsale/WhitelistCrowdsale.sol';
import './Crowdsale/WhitelistCappedCrowdsale.sol';
import './Crowdsale/WhitelistTimedCrowdsale.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../ESE.sol';

contract Presale is WhitelistCrowdsale, WhitelistCappedCrowdsale, WhitelistTimedCrowdsale {
    uint256 public privateRoundPercent = 2000;
    uint256 public liquidityAddedPercent = 5000;
    uint256 public oneYear = 86400 * 365;
    uint256 public minPurchaseAmount;
    constructor(
        uint256 rate,
        address payable wallet,
        IERC20 token,
        uint256 _minPurchaseAmount,
        uint256 cap,
        uint256 openingTime,
        uint256 closingTime,
        bytes32 whiteListMerkleRoot
    )
        WhitelistCrowdsale(rate, wallet, token, whiteListMerkleRoot)
        WhitelistCappedCrowdsale(cap)
        WhitelistTimedCrowdsale(openingTime, closingTime)
    {
        require(minPurchaseAmount <= cap, "Crowdsale: minimum purchase amount can't be more than cap");
        minPurchaseAmount = _minPurchaseAmount;
    }
    function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal onlyWhileOpen override(WhitelistCappedCrowdsale, WhitelistTimedCrowdsale, WhitelistCrowdsale) view {
        require(weiAmount >= minPurchaseAmount, "Crowdsale: you can't buy less than minimum purchase amount.");
        super._preValidatePurchase(beneficiary, weiAmount);
        require(weiRaised() + weiAmount <= cap(), "CappedCrowdsale: cap exceeded");
    }
    function _deliverTokens(
        address _beneficiary,
        uint256 _tokenAmount
    )
        internal override
    {
        ESE _token = ESE(address(token()));
        _token.transfer(_beneficiary, _tokenAmount);
        uint256 presalePrivateTokensAmount = (_tokenAmount * privateRoundPercent) / _denominator();
        uint256 presaleLiquidityAddedTokensAmount = (_tokenAmount * liquidityAddedPercent) / _denominator();
        _token.lockPresalePrivateTokens(_beneficiary, presalePrivateTokensAmount);
        _token.lockPresaleLiquidityTokens(_beneficiary, presaleLiquidityAddedTokensAmount);
        _token.lockTokens(_beneficiary, _tokenAmount - presalePrivateTokensAmount - presaleLiquidityAddedTokensAmount, block.timestamp + oneYear);
    }
    function _denominator() internal pure returns (uint96) {
        return 10000;
    }
}