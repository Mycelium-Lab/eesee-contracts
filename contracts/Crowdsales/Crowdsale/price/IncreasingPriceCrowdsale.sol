pragma solidity 0.8.17;

import "../validation/TimedCrowdsale.sol";

/**
 * @title IncreasingPriceCrowdsale
 * @dev Extension of Crowdsale contract that increases the price of tokens linearly in time.
 * Note that what should be provided to the constructor is the initial and final _rates_, that is,
 * the amount of tokens per wei contributed. Thus, the initial rate must be greater than the final rate.
 */
abstract contract IncreasingPriceCrowdsale is TimedCrowdsale {

    uint256 private _initialRate;
    uint256 private _finalRate;

    /**
     * @dev Constructor, takes initial and final rates of tokens received per wei contributed.
     * @param __initialRate Number of tokens a buyer gets per wei at the start of the crowdsale
     * @param __finalRate Number of tokens a buyer gets per wei at the end of the crowdsale
     */
    constructor (uint256 __initialRate, uint256 __finalRate) {
        require(__finalRate > 0, "IncreasingPriceCrowdsale: final rate is 0");
        // solhint-disable-next-line max-line-length
        require(__initialRate > __finalRate, "IncreasingPriceCrowdsale: initial rate is not greater than final rate");
        _initialRate = __initialRate;
        _finalRate = __finalRate;
    }

    /**
     * The base rate function is overridden to revert, since this crowdsale doesn't use it, and
     * all calls to it are a mistake.
     */
    function rate() public override view returns (uint256) {
        revert("IncreasingPriceCrowdsale: rate() called");
    }

    /**
     * @return the initial rate of the crowdsale.
     */
    function initialRate() public view returns (uint256) {
        return _initialRate;
    }

    /**
     * @return the final rate of the crowdsale.
     */
    function finalRate() public view returns (uint256) {
        return _finalRate;
    }

    /**
     * @dev Returns the rate of tokens per wei at the present time.
     * Note that, as price _increases_ with time, the rate _decreases_.
     * @return The number of tokens a buyer gets per wei at a given time
     */
    function getCurrentRate() public view returns (uint256) {
        if (!isOpen()) {
            return 0;
        }

        // solhint-disable-next-line not-rely-on-time
        uint256 elapsedTime = block.timestamp - openingTime();
        uint256 timeRange = closingTime() - openingTime();
        uint256 rateRange = _initialRate - _finalRate;
        return _initialRate - (elapsedTime * rateRange / timeRange);
    }

    /**
     * @dev Overrides parent method taking into account variable rate.
     * @param weiAmount The value in wei to be converted into tokens
     * @return The number of tokens _weiAmount wei will buy at present time
     */
    function _getTokenAmount(uint256 weiAmount) internal override view returns (uint256) {
        uint256 currentRate = getCurrentRate();
        return currentRate * weiAmount;
    }
}
