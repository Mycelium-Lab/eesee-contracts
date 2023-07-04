// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract eeseeFeeSplitter is Ownable {
    ///@dev ESE token.
    IERC20 public ESE;
    ///@dev Company treasury address & fee share Note: Cannot be more than 50%.
    FeeInfo public companyTreasury;
    ///@dev Mining pool address & fee share.
    FeeInfo public miningPool;
    ///@dev Dao treasury address & fee share.
    FeeInfo public daoTreasury;
    ///@dev Staking pool address & fee share.
    FeeInfo public stakingPool;
    ///@dev Denominator for fee amount calculation. [1 ether == 100%].
    uint256 private constant denominator = 1 ether;

    /**
     * @dev FeeInfo:
     * {addr} - Address the fees are sent to.
     * {share} - Percentage of fees to send to {addr}.
     */
    struct FeeInfo {
        address addr;
        uint256 share;
    }

    event SetShares(
        uint256 newCompanyTreasuryShare, 
        uint256 newMiningPoolShare, 
        uint256 newDaoTreasuryShare, 
        uint256 newStakingPoolShare
    );
    event SplitFees(
        address indexed companyTreasuryAddress,
        uint256 companyTreasuryAmount, 
        uint256 miningPoolAmount,
        uint256 daoTreasuryAmount,
        uint256 stakingPoolAmount
    );
    event SetCompanyTreasuryAddress(
        address indexed previousCompanyTreasury,
        address indexed newCompanyTreasury
    );

    error ZeroBalance();
    error InvalidShares();
    error InvalidAddress();
    error InvalidCompanyTreasuryShare();

    constructor (
        address _ESE, 
        FeeInfo memory _companyTreasury,
        FeeInfo memory _miningPool,
        FeeInfo memory _daoTreasury,
        FeeInfo memory _stakingPool
    ) {
        if(
            _ESE == address(0) ||
            _companyTreasury.addr == address(0) || 
            _miningPool.addr == address(0) || 
            _daoTreasury.addr == address(0) || 
            _stakingPool.addr == address(0)
        ) revert InvalidAddress();

        ESE = IERC20(_ESE);

        companyTreasury.addr = _companyTreasury.addr;
        miningPool.addr = _miningPool.addr;
        daoTreasury.addr = _daoTreasury.addr;
        stakingPool.addr = _stakingPool.addr;
        setShares(_companyTreasury.share, _miningPool.share, _daoTreasury.share, _stakingPool.share);
    }

    /**
     * @dev Splits fees between mining pool, dao treasury, staking pool and company treasury.
     */
    function splitFees() external{
        uint256 initialBalance = ESE.balanceOf(address(this));
        if(initialBalance == 0) revert ZeroBalance();

        uint256 miningPoolAmount = initialBalance * miningPool.share / denominator;
        uint256 daoTreasuryAmount = initialBalance * daoTreasury.share / denominator;
        uint256 stakingPoolAmount = initialBalance * stakingPool.share / denominator;
        uint256 companyTreasuryAmount = initialBalance - miningPoolAmount - stakingPoolAmount - daoTreasuryAmount;
        
        ESE.transfer(miningPool.addr, miningPoolAmount);
        ESE.transfer(daoTreasury.addr, daoTreasuryAmount);
        ESE.transfer(stakingPool.addr, stakingPoolAmount);
        ESE.transfer(companyTreasury.addr, companyTreasuryAmount);
        
        emit SplitFees(
            companyTreasury.addr,
            companyTreasuryAmount,
            miningPoolAmount,
            daoTreasuryAmount,
            stakingPoolAmount
        );
    }

    /**
     * @dev Sets fee shares percentage shares.
     * @param companyTreasuryShare - New company treasury share.
     * @param miningPoolShare - New mining pool share.
     * @param daoTreasuryShare - New dao treasury share.
     * @param stakingPoolShare - New staking pool share.
     */
    function setShares(uint256 companyTreasuryShare, uint256 miningPoolShare, uint256 daoTreasuryShare, uint256 stakingPoolShare) public onlyOwner {
        if (companyTreasuryShare + miningPoolShare + daoTreasuryShare + stakingPoolShare != denominator) revert InvalidShares();
        if (companyTreasuryShare > 0.5 ether) revert InvalidCompanyTreasuryShare();

        companyTreasury.share = companyTreasuryShare;
        miningPool.share = miningPoolShare;
        daoTreasury.share = daoTreasuryShare;
        stakingPool.share = stakingPoolShare;

        emit SetShares(companyTreasury.share, miningPool.share, daoTreasury.share, stakingPool.share);
    }

    /**
     * @dev Sets company treasury address.
     * @param newCompanyTreasury - New company treasury address.
     */
    function setCompanyTreasuryAddress(address newCompanyTreasury) external onlyOwner {
        if(newCompanyTreasury == address(0)) revert InvalidAddress();
        emit SetCompanyTreasuryAddress(companyTreasury.addr, newCompanyTreasury);
        companyTreasury.addr = newCompanyTreasury;
    }
}