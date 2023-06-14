// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ESE is ERC20 {
    struct Beneficiary{
        uint256 amount;
        address addr;
    }

    struct CrowdsaleVestingParams{
        //uint256 amount;
        uint256 cliff;
        uint256 duration;
        mapping(address => uint256) amounts;
        //Beneficiary[] beneficiaries;
    }

    ///@dev Presale params.
    CrowdsaleVestingParams public immutable presale;
    ///@dev Private sale params.
    CrowdsaleVestingParams public immutable privateSale;
    ///@dev Public sale params.
    CrowdsaleVestingParams public immutable publicSale;

    ///@dev Token generation event.
    uint256 public immutable TGE;

    constructor(
        uint256 amount, 
        CrowdsaleVestingParams memory _presale,
        CrowdsaleVestingParams memory _privateSale,
        CrowdsaleVestingParams memory _publicSale
    ) ERC20("eesee", "ESE") {
        if (amount == 0) revert();

        TGE = block.timestamp;

        presale = _presale;
        //TODO: also add TGE mint to beneficiaries
        //TODO: add global TGE mint

        
        //TODO: IDO
        //TODO: liquidity
        //TODO: DAO
        //TODO: marketing
        //TODO: airdrop
        //TODO: dev team

        //TODO: remove this
        _mint(msg.sender, amount);
    }

    /**
     * @dev Returns locked tokens for an {_address}.
     * @param _address - Address to check.
     
     * @return uint256 - Amount of tokens locked.
     */
    function lockedAmount(address _address) external view returns (uint256) {
        return _lockedAmount(_address);
    }

    /**
     * @dev Returns tokens available for an {_address} to transfer.
     * @param _address - Address to check.
     
     * @return uint256 - Amount of tokens available.
     */
    function available(address _address) external view returns (uint256) {
        return balanceOf(_address) - _lockedAmount(_address);
    }

    function _lockedAmount(address _address) private view returns (uint256 amount) {
        if(presaleTokens[_address] != 0 && block.timestamp - presaleStart < presaleUnlockTime){
            amount = presaleTokens[_address] / 2;
        }

        if(lockPrivateSale && privateSaleTokens[_address] != 0){
            uint256 privateSalePeriodsPassed = (block.timestamp - privateSaleStart) / privateSalePeriodTime;
            if(privateSalePeriodsPassed > privateSalePeriods){
                return amount;
            }
            amount += privateSaleTokens[_address] * (privateSalePeriods - privateSalePeriodsPassed) / privateSalePeriods;
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        if(from == address(presale)){
            presaleTokens[to] += amount;
        } else if(from == address(privateSale)){
            privateSaleTokens[to] += amount;
        } else if(from != address(0)) {
            if((balanceOf(from) - _lockedAmount(from)) < amount) revert TransferingLockedTokens(_lockedAmount(from));
        }
    }
}