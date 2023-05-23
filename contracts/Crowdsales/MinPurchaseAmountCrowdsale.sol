pragma solidity 0.8.17;

import './Crowdsale/Crowdsale.sol';

abstract contract MinPurchaseAmountCrowdsale is Crowdsale{
    uint256 public minPurchaseAmount;

    constructor (uint256 _minPurchaseAmount) {
        minPurchaseAmount = _minPurchaseAmount;
    }

    function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal override view {
        uint256 tokens = _getTokenAmount(weiAmount);
        require(tokens > minPurchaseAmount, "Crowdsale: you can't buy less than minimum purchase amount.");
        super._preValidatePurchase(beneficiary, weiAmount);
    }
}