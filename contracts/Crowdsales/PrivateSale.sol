pragma solidity 0.8.17;

import './Crowdsale/WhitelistCrowdsale.sol';
import './Crowdsale/WhitelistCappedCrowdsale.sol';
import './Crowdsale/WhitelistTimedCrowdsale.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../ESE.sol';

contract PrivateSale is WhitelistCrowdsale, WhitelistCappedCrowdsale, WhitelistTimedCrowdsale {
    uint256 sixtyDaysPercent = 1000;
    uint256 sixtyDays = 86400 * 60;
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
        uint256 tokenAmountPerSixtyDays = (_tokenAmount * sixtyDaysPercent) / _denominator();
        uint256 tokenAmountLastSixtyDays = _tokenAmount - tokenAmountPerSixtyDays * 9;
        for(uint i = 0; i < 10; i ++ ) {
            if (i != 9) {
                _token.lockTokens(_beneficiary, tokenAmountPerSixtyDays, block.timestamp + (i + 1) * sixtyDays);
            } else {
                _token.lockTokens(_beneficiary, tokenAmountLastSixtyDays, block.timestamp + (i + 1) * sixtyDays);
            }
        }
    }
    function _denominator() internal pure returns (uint96) {
        return 10000;
    }
}