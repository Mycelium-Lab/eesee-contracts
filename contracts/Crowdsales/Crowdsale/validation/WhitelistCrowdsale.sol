pragma solidity 0.8.17;
import "../Crowdsale.sol";


/**
 * @title WhitelistCrowdsale
 * @dev Crowdsale in which only whitelisted users can contribute.
 */
abstract contract WhitelistCrowdsale is Crowdsale {
    bytes32 public whiteListMerkleRoot;
    constructor (bytes32 _whiteListMerkleRoot) {
        whiteListMerkleRoot = _whiteListMerkleRoot;
    }
    function verifyCanPurchase(address claimer, bytes32[] memory merkleProof) public view returns (bool) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(claimer))));
        return MerkleProof.verify(merkleProof, whiteListMerkleRoot, leaf);
    }
    function buyTokens(address beneficiary, bytes32[] memory merkleProof) public virtual nonReentrant payable {
        require(verifyCanPurchase(beneficiary, merkleProof), "WhitelistCrowdsale: beneficiary address is not in the whitelist");
        uint256 weiAmount = msg.value;
        _preValidatePurchase(beneficiary, weiAmount);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(weiAmount);

        // update state
        _weiRaised = _weiRaised + weiAmount;

        _processPurchase(beneficiary, tokens);
        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);

        _updatePurchasingState(beneficiary, weiAmount);

        _forwardFunds();
        _postValidatePurchase(beneficiary, weiAmount);
    }
    function buyTokens(address) public override nonReentrant payable {
        revert("WhitelistCrowdsale: you must pass merkle proof in buyTokens function");
    }
}