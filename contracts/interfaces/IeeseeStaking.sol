// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IeeseeStaking {
    /**
     * @dev TierData:
     * {volumeBreakpoint} - Max volume to apply flexibleRewardRate/lockedRewardRate for.
     * {rewardRateFlexible} - Reward per token per second for flexible staking. [10^18 = 1]
     * {rewardRateLocked} - Reward per token per second for locked staking. [10^18 = 1]
     */
    struct TierData{
        uint256 volumeBreakpoint;
        uint256 rewardRateFlexible;
        uint256 rewardRateLocked;
    }

    /**
     * @dev StakerDataFlexible:
     * {stake} - Current stake.
     * {reward} - Pending reward. 
     * {lastStakedTimestamp} - Timestamp of the last action.
     */
    struct StakerDataFlexible {
        uint256 stake;
        uint256 reward;
        uint256 lastStakedTimestamp;
    }

    /**
     * @dev StakesLocked:
     * {stake} - Stake.
     * {reward} - Reward earned.
     * {unlockTime} - Timestamp of stake + reward unlock.
     */
    struct StakesLocked {
        uint256 stake;
        uint256 reward;
        uint256 unlockTime;
    }

    /**
     * @dev StakerDataLocked:
     * {stakerData.stake} - Stakes unlocked. Note: Used as a partial intermediate storage for unlocked stakes after {stakeLocked} function call. Do not use for stake calulations, use {stakeUnlocked} or {getStakeLocked} instead.
     * {stakerData.reward} - Pending reward. 
     * {stakerData.lastStakedTimestamp} - Timestamp of the last action.
     * {StakesDataLocked} - Locked stakes data. 
     */
    struct StakerDataLocked {
        StakerDataFlexible stakerData;
        StakesLocked[10] stakes;
    }

    function ESE() external view returns(IERC20);
    function eesee() external view returns(address);

    function volume(address) external view returns(uint256);
    function tierData(uint256) external view returns(uint256 volumeBreakpoint, uint256 flexibleRewardRate, uint256 lockedRewardRate);
    function stakersFlexible(address) external view returns(uint256 stake, uint256 reward, uint256 lastStakedTimestamp);
    function stakersLocked(address) external view returns(StakerDataFlexible memory stakerData);
    function duration() external view returns(uint256);

    error InvalidAmount();
    error InvalidStake();
    error InvalidRecipient();
    error InvalidDelta();
    error InsufficientStake();
    error InsufficientReward();
    error TooManyLockedStakes();
    error CallerNotEesee();

    event StakeFlexible(address indexed staker, uint256 amount);
    event UnstakeFlexible(address indexed staker, address indexed recipient, uint256 amount);
    event StakeLocked(address indexed staker, uint256 amount, uint256 unlockTime);
    event UnstakeLocked(address indexed staker, address indexed recipient, uint256 amount);
    event ChangeDuration(uint256 indexed previousDuration, uint256 indexed newDuration);

    function stakeFlexible(uint256 amount) external;
    function unstakeFlexible(uint256 amount, address recipient) external returns (uint256 ESEReceived);
    function earnedFlexible(address staker) external view returns (uint256);
    function rewardRateFlexible(address _address) external view returns (uint256);

    function stakeLocked(uint256 amount) external;
    function unstakeLocked(uint256 amount, address recipient) external returns (uint256 ESEReceived);
    function stakeUnlocked(address staker) external view returns (uint256 stake);
    function getStakeLocked(address staker) external view returns (uint256 stake);
    function earnedLocked(address staker) external view returns (uint256);
    function stakesLocked(address staker) external view returns (StakesLocked[10] memory stakes);
    function rewardRateLocked(address _address) external view returns (uint256);

    function updateVolume(int256 delta, address _address) external;
    function changeDuration(uint256 _duration) external;
}
