pragma solidity 0.8.17;

import "../Crowdsale.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title IndividuallyCappedCrowdsale
 * @dev Crowdsale with per-beneficiary caps.
 */
abstract contract IndividuallyCappedCrowdsale is Crowdsale, AccessControl {
    bytes32 public constant CAPPER_ROLE =  keccak256("capper");
    mapping(address => uint256) private _contributions;
    mapping(address => uint256) private _caps;
    constructor () {
        grantRole(CAPPER_ROLE, msg.sender);
    }
    /**
     * @dev Sets a specific beneficiary's maximum contribution.
     * @param beneficiary Address to be capped
     * @param cap Wei limit for individual contribution
     */
    function setCap(address beneficiary, uint256 cap) external onlyRole(CAPPER_ROLE) {
        _caps[beneficiary] = cap;
    }

    /**
     * @dev Returns the cap of a specific beneficiary.
     * @param beneficiary Address whose cap is to be checked
     * @return Current cap for individual beneficiary
     */
    function getCap(address beneficiary) public view returns (uint256) {
        return _caps[beneficiary];
    }

    /**
     * @dev Returns the amount contributed so far by a specific beneficiary.
     * @param beneficiary Address of contributor
     * @return Beneficiary contribution so far
     */
    function getContribution(address beneficiary) public view returns (uint256) {
        return _contributions[beneficiary];
    }

    /**
     * @dev Extend parent behavior requiring purchase to respect the beneficiary's funding cap.
     * @param beneficiary Token purchaser
     * @param weiAmount Amount of wei contributed
     */
    function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal override view {
        super._preValidatePurchase(beneficiary, weiAmount);
        // solhint-disable-next-line max-line-length
        require(_contributions[beneficiary] + weiAmount <= _caps[beneficiary], "IndividuallyCappedCrowdsale: beneficiary's cap exceeded");
    }

    /**
     * @dev Extend parent behavior to update beneficiary contributions.
     * @param beneficiary Token purchaser
     * @param weiAmount Amount of wei contributed
     */
    function _updatePurchasingState(address beneficiary, uint256 weiAmount) internal override {
        super._updatePurchasingState(beneficiary, weiAmount);
        _contributions[beneficiary] = _contributions[beneficiary] + weiAmount;
    }
}
