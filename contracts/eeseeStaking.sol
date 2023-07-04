// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./interfaces/IeeseeStaking.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract eeseeStaking is IeeseeStaking, Ownable {
    using SafeERC20 for IERC20;

    ///@dev ESE token to use in staking.
    IERC20 public immutable ESE;
    ///@dev eesee marketplace contract to track volume changes.
    address public immutable eesee;

    ///@dev Tier data describing volume breakpoints & rewardRates.
    TierData[] public tierData;
    ///@dev Volume for each user on eesee marketplace.
    mapping(address => uint256) public volume;
    ///@dev Data for each staker.
    mapping(address => StakerDataFlexible) public stakersFlexible;
    mapping(address => StakerDataLocked) public stakersLocked;

    ///@dev Min locked staking duration.
    uint256 public duration = 90 days;
    ///@dev Maximum amount of locked stakes that can be staked at one time.
    uint256 constant public maxStakesLocked = 10;
    ///@dev Denominator for reward rates.
    uint256 constant private denominator = 1 ether;

    constructor(address _ESE, address _eesee, TierData[] memory _tierData) {
        if(_ESE == address(0)) revert("eeseeStaking: Invalid Token");
        if(_eesee == address(0)) revert("eeseeStaking: Invalid eesee");
        if(_tierData.length == 0) revert("eeseeStaking: Invalid tiers Length");
        for(uint256 i; i < _tierData.length;){
            tierData.push(_tierData[i]);
            unchecked{i++;}
        }
        ESE = IERC20(_ESE);
        eesee = _eesee;
    }

    //============= Flexible staking ==============

    /**
     * @dev Stakes ESE token using flexible staking scheme. The staker can withdraw tokens anytime using {unstakeFlexible} function.
     * @param amount - Amount of ESE tokens to stake.
     */
    function stakeFlexible(uint256 amount) external {
        if(amount == 0) revert InvalidAmount();
        ESE.safeTransferFrom(msg.sender, address(this), amount);

        StakerDataFlexible storage staker = stakersFlexible[msg.sender];
        unchecked{        //Can't overflow because ESE's supply is limited
            staker.reward += _calculateRewardFlexible(msg.sender);
            staker.stake += amount;
        }
        staker.lastStakedTimestamp = block.timestamp;

        emit StakeFlexible(msg.sender, amount);
    }

    /**
     * @dev Unstakes ESE token from flexible staking and sends them to {recipient}. Also sends reward tokens. Pass 0 to {amount} to only receive rewards.
     * @param amount - Amount of ESE tokens to unstake.
     * @param recipient - Tokens receiver.

     * @return ESEReceived - ESE tokens sent.
     */
    function unstakeFlexible(uint256 amount, address recipient) external returns (uint256 ESEReceived){
        if(recipient == address(0)) revert InvalidRecipient();
        StakerDataFlexible storage staker = stakersFlexible[msg.sender];
        if(amount > staker.stake) revert InsufficientStake();
        unchecked{
            //Can't overflow because ESE's supply is limited
            uint256 reward = staker.reward + _calculateRewardFlexible(msg.sender);
            staker.reward = 0;
            staker.lastStakedTimestamp = block.timestamp;
            if(amount != 0){
                staker.stake -= amount;
            } else if(reward == 0) revert InsufficientReward();

            ESEReceived = amount + reward;
        }
        ESE.safeTransfer(recipient, ESEReceived);

        emit UnstakeFlexible(msg.sender, recipient, ESEReceived);
    }

    /**
     * @dev Returns how many reward tokens were earned by {staker} from flexible staking.
     * @param staker - Address to check.

     * @return uint256 - Amount of reward tokens ready to be collected.
     */
    function earnedFlexible(address staker) external view returns (uint256) {
        unchecked{ //Can't overflow because ESE's supply is limited
            return stakersFlexible[staker].reward + _calculateRewardFlexible(staker);
        }
    }

    /**
     * @dev Returns reward per second per token staked for {_address} for flexible staking.
     * @param _address - Address to check.

     * @return uint256 - Reward per second per token staked.
     */
    function rewardRateFlexible(address _address) public view returns (uint256){
        unchecked{
            uint256 length = tierData.length - 1;
            for(uint256 i; i < length; i++) {
                if(volume[_address] < tierData[i].volumeBreakpoint){
                    return tierData[i].rewardRateFlexible;
                }
            }
            return tierData[length].rewardRateFlexible;
        }
    }

    function _calculateRewardFlexible(address _address) internal view returns (uint256) {
        StakerDataFlexible storage staker = stakersFlexible[_address];
        if(staker.stake > 0){
            return staker.stake * rewardRateFlexible(_address) * (block.timestamp - staker.lastStakedTimestamp) / denominator;
        }
        return 0;
    }

    //============= Locked staking ==============

    /**
     * @dev Stakes ESE token using locked staking scheme. The staker can only withdraw tokens after {duration} has passed.
     * @param amount - Amount of ESE tokens to stake.
     * Note: Staker can only have {maxStakesLocked} stakes at one single time. Reverts if more is staked before any other one expires.
     */
    function stakeLocked(uint256 amount) external {
        if(amount == 0) revert InvalidAmount();
        ESE.safeTransferFrom(msg.sender, address(this), amount);

        StakerDataLocked storage staker = stakersLocked[msg.sender];
        _updateLockedRewards(staker);

        // Set new stake for the first unlocked stake in staker.stakes array
        bool hasUnlockedStakes;
        for(uint256 i; i < maxStakesLocked;) {
            if(block.timestamp < staker.stakes[i].unlockTime){
                unchecked{ i++; }
                continue;
            }

            unchecked{
                staker.stakerData.stake += staker.stakes[i].stake;
            }
            staker.stakes[i].stake = amount;

            uint256 unlockTime = block.timestamp + duration;
            staker.stakes[i].unlockTime = unlockTime; 

            hasUnlockedStakes = true;
            emit StakeLocked(msg.sender, amount, unlockTime);
            break;
        }

        if(!hasUnlockedStakes) revert TooManyLockedStakes();
        staker.stakerData.lastStakedTimestamp = block.timestamp;
    }

    /**
     * @dev Unstakes ESE token from locked staking and sends them to {recipient}. Also sends reward tokens. Pass 0 to {amount} to only receive rewards.
     * @param amount - Amount of ESE tokens to unstake.
     * @param recipient - Tokens receiver.

     * @return ESEReceived - ESE tokens sent.
     */
    function unstakeLocked(uint256 amount, address recipient) external returns (uint256 ESEReceived){
        if(recipient == address(0)) revert InvalidRecipient();
        StakerDataLocked storage staker = stakersLocked[msg.sender];
        _updateLockedRewards(staker);

        uint256 _amount = amount;
        unchecked{
            // Sub amount from each stake iteratively
            for(uint256 i; i < maxStakesLocked; i++) {
                if(staker.stakes[i].unlockTime == 0){
                    // There are no initialized stakes after this one, break
                    break;
                }
                if(staker.stakes[i].stake == 0 || block.timestamp < staker.stakes[i].unlockTime){ 
                    continue;
                }
                if(staker.stakes[i].stake < _amount){
                    _amount -= staker.stakes[i].stake;
                    staker.stakes[i].stake = 0;
                    continue;
                }
                // This is the last stake to fully fill amount, break
                staker.stakes[i].stake -= _amount;
                _amount = 0;
                break;
            }

            if(staker.stakerData.stake < _amount) revert InsufficientStake();
            staker.stakerData.stake -= _amount;
        }

        unchecked{ //Can't overflow because ESE's supply is limited
            ESEReceived = amount + staker.stakerData.reward;
        }
        if(ESEReceived == 0) revert InsufficientReward();
        ESE.safeTransfer(recipient, ESEReceived);

        staker.stakerData.reward = 0;
        staker.stakerData.lastStakedTimestamp = block.timestamp;

        emit UnstakeLocked(msg.sender, recipient, ESEReceived);
    }

    /**
     * @dev Returns stakes unlocked for {staker}.
     * @param staker - Address to check.

     * @return stake - Amount unlocked.
     */
    function stakeUnlocked(address staker) external view returns (uint256 stake) {
        StakerDataLocked storage _staker = stakersLocked[staker];
        unchecked{ //Can't overflow because ESE's supply is limited
            for(uint256 i; i < maxStakesLocked; i++) {
                if(_staker.stakes[i].unlockTime == 0){
                    // There are no initialized stakes after this one, break
                    break;
                }
                if(block.timestamp >= _staker.stakes[i].unlockTime){  
                    stake += _staker.stakes[i].stake;
                }
            }
            stake += _staker.stakerData.stake;
        }
    }

    /**
     * @dev Returns total stake for {staker}, unlocked + locked, without reward.
     * @param staker - Address to check.

     * @return stake - Amount staked.
     */
    function getStakeLocked(address staker) external view returns (uint256 stake) {
        StakerDataLocked storage _staker = stakersLocked[staker];
        unchecked{ // Can't overflow because ESE's supply is limited
            for(uint256 i; i < maxStakesLocked; i++) {
                if(_staker.stakes[i].unlockTime == 0){
                    // There are no initialized stakes after this one, break
                    break;
                }
                stake += _staker.stakes[i].stake;
            }
            stake += _staker.stakerData.stake;
        }
    }

    /**
     * @dev Returns how many reward tokens were earned by {staker} from locked staking.
     * @param staker - Address to check.

     * @return reward - Amount of reward tokens ready to be collected.
     */
    function earnedLocked(address staker) external view returns (uint256 reward) {
        StakerDataLocked storage _staker = stakersLocked[staker];
        unchecked{ // Can't overflow because ESE's supply is limited
            for(uint256 i; i < maxStakesLocked; i++) {
                if(_staker.stakes[i].unlockTime == 0){
                    // There are no initialized stakes after this one, break
                    break;
                }
                if(block.timestamp < _staker.stakes[i].unlockTime){  
                    continue;
                }
                if(_staker.stakes[i].stake != 0){
                    reward += _calculateRewardLocked(staker, _staker.stakes[i].stake);
                }
                reward += _staker.stakes[i].reward;
            }
            if(_staker.stakerData.stake != 0){
                reward += _calculateRewardLocked(staker, _staker.stakerData.stake);
            }
            reward += _staker.stakerData.reward;
        }
    }

    /**
     * @dev Returns all stakes of {staker} for locked staking.
     * @param staker - Address to check.

     * @return stakes - All {staker}'s stakes.
     */
    function stakesLocked(address staker) external view returns (StakesLocked[maxStakesLocked] memory stakes) {
        return stakersLocked[staker].stakes;
    }
    
    /**
     * @dev Returns reward per second per token staked for {_address} for locked staking.
     * @param _address - Address to check.

     * @return uint256 - Reward per second per token staked.
     */
    function rewardRateLocked(address _address) public view returns (uint256){
        unchecked{ 
            uint256 length = tierData.length - 1;
            for(uint256 i; i < length; i++) {
                if(volume[_address] < tierData[i].volumeBreakpoint){
                    return tierData[i].rewardRateLocked;
                }
            }
            return tierData[length].rewardRateLocked;
        }
    }

    function _calculateRewardLocked(address _address, uint256 stake) internal view returns (uint256) {
        return stake * rewardRateLocked(_address) * (block.timestamp - stakersLocked[_address].stakerData.lastStakedTimestamp) / denominator;
    }

    function _updateLockedRewards(StakerDataLocked storage staker) internal {
        uint256 reward;
        unchecked{ // Can't overflow because ESE's supply is limited
            for(uint256 i; i < maxStakesLocked; i++) {
                if(staker.stakes[i].unlockTime == 0){
                    // There are no initialized stakes after this one, break
                    break;
                }
                if(staker.stakes[i].stake != 0){
                    staker.stakes[i].reward += _calculateRewardLocked(msg.sender, staker.stakes[i].stake);
                }
                if(block.timestamp >= staker.stakes[i].unlockTime) {
                    reward += staker.stakes[i].reward;
                    staker.stakes[i].reward = 0;
                }
            }
            if(staker.stakerData.stake != 0){
                staker.stakerData.reward += _calculateRewardLocked(msg.sender, staker.stakerData.stake);
            }
            staker.stakerData.reward += reward;
        }
    }

    //============== Volume Updates ==============

    /**
     * @dev Updates {_address}'s volume on eesee platform and rewards.
     * @param delta - Volume change.
     * @param _address - Address to update.
     * Note: This function can only be called by eesee marketplace.
     */
    function updateVolume(int256 delta, address _address) external {
        if(msg.sender != eesee) revert CallerNotEesee();

        StakerDataFlexible storage stakerFlexible = stakersFlexible[_address];
        unchecked{ //Can't overflow because ESE's supply is limited
            stakerFlexible.reward += _calculateRewardFlexible(_address);
        }
        stakerFlexible.lastStakedTimestamp = block.timestamp;

        StakerDataLocked storage stakerLocked = stakersLocked[_address];
        unchecked{ //Can't overflow because ESE's supply is limited
            for(uint256 i; i < maxStakesLocked; i++) {
                if(stakerLocked.stakes[i].unlockTime == 0){
                    // There are no initialized stakes after this one, break
                    break;
                }
                if(stakerLocked.stakes[i].stake != 0){  
                    stakerLocked.stakes[i].reward += _calculateRewardLocked(_address, stakerLocked.stakes[i].stake);
                }
            }
            if(stakerLocked.stakerData.stake != 0){
                stakerLocked.stakerData.reward += _calculateRewardLocked(_address, stakerLocked.stakerData.stake);
            }
        }
        stakerLocked.stakerData.lastStakedTimestamp = block.timestamp;

        int256 _volume = int256(volume[_address]) + delta;
        if(_volume < 0) revert InvalidDelta();
        volume[_address] = uint256(_volume);
    }

    //================ Admin ==================

    /**
     * @dev Changes duration. Emits {ChangeDuration} event.
     * @param _duration - New duration.
     * Note: This function can only be called by owner.
     */
    function changeDuration(uint256 _duration) external onlyOwner {
        emit ChangeDuration(duration, _duration);
        duration = _duration;
    }
}