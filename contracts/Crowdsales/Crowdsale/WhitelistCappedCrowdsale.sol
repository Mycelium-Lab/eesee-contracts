pragma solidity 0.8.17;

import "./WhitelistCrowdsale.sol";

/**
 * @title CappedCrowdsale
 * @dev Crowdsale with a limit for total contributions.
 */
abstract contract WhitelistCappedCrowdsale is WhitelistCrowdsale {

    uint256 private _cap;

    /**
     * @dev Constructor, takes maximum amount of wei accepted in the crowdsale.
     * @param __cap Max amount of wei to be contributed
     */
    constructor (uint256 __cap) {
        require(__cap > 0, "CappedCrowdsale: cap is 0");
        _cap = __cap;
    }

    /**
     * @return the cap of the crowdsale.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }

    /**
     * @dev Checks whether the cap has been reached.
     * @return Whether the cap was reached
     */
    function capReached() public view returns (bool) {
        return weiRaised() >= _cap;
    }

    /**
     * @dev Extend parent behavior requiring purchase to respect the funding cap.
     * @param beneficiary Token purchaser
     * @param weiAmount Amount of wei contributed
     */
    function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal override virtual view {
        super._preValidatePurchase(beneficiary, weiAmount);
        require(weiRaised() + weiAmount <= _cap, "CappedCrowdsale: cap exceeded");
    }
}
