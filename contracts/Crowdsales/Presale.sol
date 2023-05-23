pragma solidity 0.8.17;

import './Crowdsale/Crowdsale.sol';
import './Crowdsale/validation/CappedCrowdsale.sol';
import './Crowdsale/validation/WhitelistCrowdsale.sol';
import './Crowdsale/validation/TimedCrowdsale.sol';
import './Crowdsale/emission/MintedCrowdsale.sol';
import './MinPurchaseAmountCrowdsale.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../ESE.sol';
contract Presale is Crowdsale, MintedCrowdsale, MinPurchaseAmountCrowdsale, CappedCrowdsale, TimedCrowdsale, WhitelistCrowdsale {
    uint256 public privateRoundPercent = 2000;
    uint256 public liquidityAddedPercent = 5000;
    uint256 public oneYear = 86400 * 365;
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