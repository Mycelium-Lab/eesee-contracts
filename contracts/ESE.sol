// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IESECrowdsale.sol";

contract ESE is ERC20 {
    ///@dev Presale contract.
    IESECrowdsale public immutable presale;
    ///@dev Presale start timestamp.
    uint256 public immutable presaleStart;
    ///@dev Time in which tokens will be unlocked.
    uint256 public immutable presaleUnlockTime;


    ///@dev Private sale contract.
    IESECrowdsale public immutable privateSale;
    ///@dev Presale start timestamp.
    uint256 public immutable privateSaleStart;
    ///@dev Periods over which tokens will be unlocked.
    uint256 public immutable privateSalePeriods;
    ///@dev Duration of each period.
    uint256 public immutable privateSalePeriodTime;

    ///@dev Tokens locked by crowdsale contract for an address.
    mapping(address => uint256) private presaleTokens;
    mapping(address => uint256) private privateSaleTokens;

    ///@dev False if ignore lock mechanism on private sales
    bool public immutable lockPrivateSale;

    error InvalidAmount();
    error InvalidCrowdsale();
    error TransferingLockedTokens(uint256 tokensLocked);

    constructor(
        uint256 amount, 
        
        uint256 _presaleAmount, // 50000000 ESE
        IESECrowdsale _presale, 
        uint256 _presaleUnlockTime,//365 days

        uint256 _privateSaleAmount, // 90000000 ESE
        IESECrowdsale _privateSale,
        uint256 _privateSalePeriods,//10
        uint256 _privateSalePeriodTime//60 days
    ) ERC20("eesee", "ESE") {
        if (amount == 0 || _presaleAmount == 0 || _privateSaleAmount == 0) revert InvalidAmount();
        if (address(_presale) == address(0) || address(_privateSale) == address(0)) revert InvalidCrowdsale();

        presale = _presale;
        presaleStart = _presale.openingTime();
        presaleUnlockTime = _presaleUnlockTime;

        privateSale = _privateSale;
        privateSaleStart = _privateSale.openingTime();
        privateSalePeriods = _privateSalePeriods;
        privateSalePeriodTime = _privateSalePeriodTime;
        lockPrivateSale = _privateSalePeriods != 0 && _privateSalePeriodTime != 0;
        
        //TODO: IDO
        //TODO: liquidity
        //TODO: DAO
        //TODO: marketing
        //TODO: airdrop
        //TODO: dev team

        //TODO: remove this
        _mint(msg.sender, amount);

        _mint(address(_presale), _presaleAmount);
        _mint(address(_privateSale), _privateSaleAmount);
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