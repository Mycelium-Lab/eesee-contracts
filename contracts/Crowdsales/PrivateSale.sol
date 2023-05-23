pragma solidity 0.8.17;

import './Crowdsale/Crowdsale.sol';
import './Crowdsale/validation/CappedCrowdsale.sol';
import './Crowdsale/validation/WhitelistCrowdsale.sol';
import './Crowdsale/emission/MintedCrowdsale.sol';
import './MinPurchaseAmountCrowdsale.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../ESE.sol';
contract PrivateSale is Crowdsale, MinPurchaseAmountCrowdsale, CappedCrowdsale, WhitelistCrowdsale, TimedCrowdsale, MintedCrowdsale {
    uint256 sixtyDaysPercent = 1000;
    uint256 sixtyDays = 86400 * 60;
    constructor(
        uint256 rate,
        address payable wallet,
        IERC20 token,
        uint256 minPurchaseAmount,
        uint256 cap,
        uint256 openingTime,
        uint256 closingTime,
        bytes32 whiteListMerkleRoot
    )
        MintedCrowdsale()
        Crowdsale(rate, wallet, token)
        MinPurchaseAmountCrowdsale(minPurchaseAmount)
        CappedCrowdsale(cap)
        TimedCrowdsale(openingTime, closingTime)
        WhitelistCrowdsale(whiteListMerkleRoot)
    {

    }
    function _deliverTokens(
        address _beneficiary,
        uint256 _tokenAmount
    )
        internal
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