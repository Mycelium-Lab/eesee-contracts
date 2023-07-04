const {
    time,
    loadFixture,
  } = require("@nomicfoundation/hardhat-network-helpers");
  const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
  const { expect } = require("chai");
  const { ethers, network } = require("hardhat");
  const assert = require("assert");
  const { getContractAddress } = require('@ethersproject/address')
  describe("eeseeStaking", function () {
    let ESE;
    let eesee;
    let signer, acc2, acc3
    let staking
    //after one year
    const zeroAddress = "0x0000000000000000000000000000000000000000"
  
    this.beforeAll(async() => {
        [signer, acc2, acc3, eesee] = await ethers.getSigners()
        const _ESE = await hre.ethers.getContractFactory("ESE");
        const _eeseeStaking = await hre.ethers.getContractFactory("eeseeStaking");

        const transactionCount = await signer.getTransactionCount()
        const futureStakingAddress = getContractAddress({
          from: signer.address,
          nonce: transactionCount + 1
        })
        
        ESE = await _ESE.deploy([{
                cliff: 0,
                duration: 0,
                TGEMintShare: 10000,
                beneficiaries: [
                    {addr: signer.address, amount: '2000000000000000000000000'}, 
                    {addr: acc2.address, amount: '100000000000000000000' },
                    {addr: futureStakingAddress, amount: '2000000000000000000000000'}
                ]
            }
        ])
        await ESE.deployed()

        staking = await _eeseeStaking.deploy(ESE.address, eesee.address, [{volumeBreakpoint: 1000, rewardRateFlexible: ethers.utils.parseUnits('1', 'ether'), rewardRateLocked: ethers.utils.parseUnits('2', 'ether')}, {volumeBreakpoint: 2000, rewardRateFlexible:  ethers.utils.parseUnits('10', 'ether'), rewardRateLocked:  ethers.utils.parseUnits('20', 'ether')}])
        await staking.deployed()

        await ESE.connect(acc2).approve(staking.address, '100000000000000000000')
        await ESE.approve(staking.address, '2000000000000000000000000')
    })
    it('Inits', async () => {
        assert.equal((await staking.duration()).toString(), 60*60*24*90, "duration is correct")
        assert.equal((await staking.ESE()).toString(), ESE.address, "ESE is correct")
        assert.equal((await staking.eesee()).toString(), eesee.address, "eesee is correct")
        assert.equal((await staking.tierData(0)).volumeBreakpoint.toString(), 1000, "volume breakpoint is correct")
        assert.equal((await staking.tierData(0)).rewardRateFlexible.toString(), ethers.utils.parseUnits('1', 'ether'), "rewardRateFlexible is correct")
        assert.equal((await staking.tierData(0)).rewardRateLocked.toString(), ethers.utils.parseUnits('2', 'ether'), "rewardRateLocked is correct")
        assert.equal((await staking.maxStakesLocked()).toString(), 10, "maxStakesLocked is correct")
    })

    it('Stakes Flexible', async () => {
        assert.equal((await staking.rewardRateFlexible(signer.address)).toString(), ethers.utils.parseUnits('1', 'ether'), "Reward rate is correct")
        await expect(staking.stakeFlexible(0)).to.be.revertedWithCustomError(staking, "InvalidAmount")

        //const timestamp = (await ethers.provider.getBlock()).timestamp + 1
        await expect(staking.stakeFlexible(1))
            .to.emit(staking, "StakeFlexible")
            .withArgs(signer.address, 1)
        const stakeTimestamp = (await ethers.provider.getBlock()).timestamp

        await time.increase(5)
        const _timestamp = (await ethers.provider.getBlock()).timestamp
        assert.equal((await staking.earnedFlexible(signer.address)).toString(), _timestamp - stakeTimestamp, "earned is correct")

        assert.equal((await staking.stakersFlexible(signer.address)).stake.toString(), '1', "stake is correct")
        assert.equal((await staking.stakersFlexible(signer.address)).reward.toString(), '0', "reward is correct")
        assert.equal((await staking.volume(signer.address)).toString(), '0', "volume is correct")
        assert.equal((await staking.stakersFlexible(signer.address)).lastStakedTimestamp.toString(), stakeTimestamp.toString(), "lastStakedTimestamp is correct")
    
        // Update volume
        await expect(staking.connect(eesee).updateVolume(-1000, signer.address)).to.be.revertedWithCustomError(staking, 'InvalidDelta')
        await expect(staking.connect(signer).updateVolume(1000, signer.address)).to.be.revertedWithCustomError(staking, 'CallerNotEesee')
        await staking.connect(eesee).updateVolume(1000, signer.address)

        //const __timestamp = (await ethers.provider.getBlock()).timestamp + 1
        await expect(staking.stakeFlexible(1))
            .to.emit(staking, "StakeFlexible")
            .withArgs(signer.address, 1)
        const earnedBefore = await staking.earnedFlexible(signer.address)
        const _stakeTimestamp = (await ethers.provider.getBlock()).timestamp

        await time.increase(5)
        const ___timestamp = (await ethers.provider.getBlock()).timestamp

        assert.equal((await staking.earnedFlexible(signer.address)).toString(), (earnedBefore.add((10*2*(___timestamp - _stakeTimestamp)).toString())).toString(), "earned is correct")
        assert.equal((await staking.stakersFlexible(signer.address)).stake.toString(), '2', "stake is correct")
        assert.equal((await staking.stakersFlexible(signer.address)).reward.toString(), earnedBefore.toString(), "reward is correct")
        assert.equal((await staking.volume(signer.address)).toString(), '1000', "volume is correct")
        assert.equal((await staking.stakersFlexible(signer.address)).lastStakedTimestamp.toString(), _stakeTimestamp.toString(), "lastStakedTimestamp is correct")
        assert.equal((await staking.rewardRateFlexible(signer.address)).toString(), ethers.utils.parseUnits('10', 'ether'), "Reward rate is correct")
    })

    it('Unstake Flexible', async () => {
        await expect(staking.unstakeFlexible(100000, acc2.address)).to.be.revertedWithCustomError(staking, "InsufficientStake")
        await expect(staking.connect(acc2).unstakeFlexible(0, acc2.address)).to.be.revertedWithCustomError(staking, "InsufficientReward")

        const balanceBefore = await ESE.balanceOf(acc2.address)
        const earnedBefore = (await staking.earnedFlexible(signer.address)).add(20)//Add 20 because unstakeFlexible happens 1 second after this call and the reward rate is 20 per second
        await expect(staking.unstakeFlexible(0, acc2.address))
            .to.emit(staking, "UnstakeFlexible")
            .withArgs(signer.address, acc2.address, earnedBefore)
        const balanceAfter = await ESE.balanceOf(acc2.address)
        assert.equal((balanceAfter.sub(balanceBefore)).toString(), earnedBefore.toString(), "reward collected is correct")

        const balanceBeforeSigner = await ESE.balanceOf(signer.address)
        const stake = (await staking.earnedFlexible(signer.address)).add(20).add(2) //We staked 2 tokens//Add 20 because unstakeFlexible happens 1 second after
        await expect(staking.unstakeFlexible(2, signer.address))
            .to.emit(staking, "UnstakeFlexible")
            .withArgs(signer.address, signer.address, stake)
        const _unstakeTimestamp = (await ethers.provider.getBlock()).timestamp

        const balanceAfterSigner = await ESE.balanceOf(signer.address)
        assert.equal((balanceAfterSigner.sub(balanceBeforeSigner)).toString(), stake.toString(), "stake collected is correct")

        assert.equal((await staking.earnedFlexible(signer.address)).toString(), '0', "earned is correct")
        assert.equal((await staking.stakersFlexible(signer.address)).stake.toString(), '0', "stake is correct")
        assert.equal((await staking.stakersFlexible(signer.address)).reward.toString(), '0', "reward is correct")
        assert.equal((await staking.stakersFlexible(signer.address)).lastStakedTimestamp.toString(), _unstakeTimestamp.toString(), "lastStakedTimestamp is correct")
    })

    it('Stake Locked', async () => {
        assert.equal((await staking.rewardRateLocked(acc2.address)).toString(), ethers.utils.parseUnits('2', 'ether'), "Reward rate is correct")
        await expect(staking.connect(acc2).stakeLocked(0)).to.be.revertedWithCustomError(staking, "InvalidAmount")

        const tx = await staking.connect(acc2).stakeLocked(1)
        const stakeTimestamp = (await ethers.provider.getBlock()).timestamp
        expect(tx).to.emit(staking, "StakeLocked").withArgs(acc2.address, 1, stakeTimestamp + 90*24*60*60)

        await time.increase(432000)//5 days
        assert.equal((await staking.earnedLocked(acc2.address)).toString(), '0', "earned is correct")

        assert.equal((await staking.stakersLocked(acc2.address)).stake.toString(), '0', "stake is correct")
        assert.equal((await staking.getStakeLocked(acc2.address)).toString(), '1', "stake is correct")
        assert.equal((await staking.stakesLocked(acc2.address))[0].stake.toString(), '1', "stake is correct")
        assert.equal((await staking.stakesLocked(acc2.address))[0].unlockTime.toString(), stakeTimestamp + 90*24*60*60, "unlockTime is correct")
        assert.equal((await staking.stakeUnlocked(acc2.address)).toString(), '0', "stakeUnlocked is correct")
        assert.equal((await staking.stakersLocked(acc2.address)).reward.toString(), '0', "reward is correct")
        assert.equal((await staking.volume(acc2.address)).toString(), '0', "volume is correct")
        assert.equal((await staking.stakersLocked(acc2.address)).lastStakedTimestamp.toString(), stakeTimestamp.toString(), "lastStakedTimestamp is correct")
    
        // Update volume
        await staking.connect(eesee).updateVolume(1000, acc2.address)
        assert.equal((await staking.volume(acc2.address)).toString(), '1000', "volume is correct")
        const timestamp = (await ethers.provider.getBlock()).timestamp
        let reward_ = (timestamp - stakeTimestamp) * 2 * 1

        for (let i = 1; i < 10; i++) {
            const tx = await staking.connect(acc2).stakeLocked(1)
            const _stakeTimestamp = (await ethers.provider.getBlock()).timestamp
            expect(tx).to.emit(staking, "StakeLocked").withArgs(acc2.address, 1, _stakeTimestamp + 90*24*60*60)

            await time.increase(432000)//5 days
            assert.equal((await staking.stakersLocked(acc2.address)).stake.toString(), '0', "stake is correct")
            assert.equal((await staking.stakersLocked(acc2.address)).reward.toString(), '0', "reward is correct")
            assert.equal((await staking.getStakeLocked(acc2.address)).toString(), (i+1).toString(), "stake is correct")
            assert.equal((await staking.earnedLocked(acc2.address)).toString(), '0', "earned is correct")
            assert.equal((await staking.stakesLocked(acc2.address))[i].stake.toString(), '1', "stake is correct")
            assert.equal((await staking.stakesLocked(acc2.address))[i].unlockTime.toString(), _stakeTimestamp + 90*24*60*60, "unlockTime is correct")
            assert.equal((await staking.stakeUnlocked(acc2.address)).toString(), '0', "stakeUnlocked is correct")
            assert.equal((await staking.stakersLocked(acc2.address)).lastStakedTimestamp.toString(), _stakeTimestamp.toString(), "lastStakedTimestamp is correct")
        }
        await expect(staking.connect(acc2).stakeLocked(1)).to.be.revertedWithCustomError(staking, "TooManyLockedStakes")
        await time.increase(3457000)//40 days

        const _tx = await staking.connect(acc2).stakeLocked(2)
        const _stakeTimestamp = (await ethers.provider.getBlock()).timestamp
        reward_ += (_stakeTimestamp - timestamp) * 20 * 1
        expect(_tx).to.emit(staking, "StakeLocked").withArgs(acc2.address, 2, _stakeTimestamp + 90*24*60*60)

        assert.equal((await staking.stakersLocked(acc2.address)).stake.toString(), '1', "stake is correct")//Stakes transfered from slot 1
        assert.equal((await staking.getStakeLocked(acc2.address)).toString(), '12', "stake is correct")
        assert.equal((await staking.stakesLocked(acc2.address))[0].stake.toString(), '2', "stake is correct")
        assert.equal((await staking.stakesLocked(acc2.address))[0].unlockTime.toString(), _stakeTimestamp + 90*24*60*60, "unlockTime is correct")
        assert.equal((await staking.stakeUnlocked(acc2.address)).toString(), '1', "stakeUnlocked is correct")
        
        assert.equal((await staking.stakersLocked(acc2.address)).reward.toString(), (await staking.earnedLocked(acc2.address)).toString(), "reward is correct")
        assert.equal((await staking.stakersLocked(acc2.address)).reward.toString(), reward_.toString(), "reward is correct")
        assert.equal((await staking.stakersLocked(acc2.address)).lastStakedTimestamp.toString(), _stakeTimestamp.toString(), "lastStakedTimestamp is correct")
    })

    it('Unstake Locked', async () => {
        await expect(staking.connect(signer).unstakeLocked(0, acc2.address)).to.be.revertedWithCustomError(staking, "InsufficientReward")
        await expect(staking.connect(acc2).unstakeLocked(2, acc2.address)).to.be.revertedWithCustomError(staking, "InsufficientStake")
    
        const balanceBefore = await ESE.balanceOf(signer.address)
        const earnedBefore = (await staking.earnedLocked(acc2.address)).add(20)//Add 20 because unstakeLocked happens 1 second after this call and the reward rate is 20 per second
        await expect(staking.connect(acc2).unstakeLocked(0, signer.address))
            .to.emit(staking, "UnstakeLocked")
            .withArgs(acc2.address, signer.address, earnedBefore)
        const balanceAfter = await ESE.balanceOf(signer.address)
        assert.equal((balanceAfter.sub(balanceBefore)).toString(), earnedBefore.toString(), "reward collected is correct")
        
        const balanceBeforeAcc2 = await ESE.balanceOf(acc2.address)
        const stake = (await staking.earnedLocked(acc2.address)).add(20).add(1) //We staked 1 tokens//Add 20 because unstakeFlexible happens 1 second after
        await expect(staking.connect(acc2).unstakeLocked(1, acc2.address))
            .to.emit(staking, "UnstakeLocked")
            .withArgs(acc2.address, acc2.address, stake)
        const _unstakeTimestamp = (await ethers.provider.getBlock()).timestamp

        const balanceAfterAcc2  = await ESE.balanceOf(acc2.address)
        assert.equal((balanceAfterAcc2.sub(balanceBeforeAcc2)).toString(), stake.toString(), "stake collected is correct")

        assert.equal((await staking.earnedLocked(acc2.address)).toString(), '0', "earned is correct")
        assert.equal((await staking.stakersLocked(acc2.address)).stake.toString(), '0', "stake is correct")
        assert.equal((await staking.stakersLocked(acc2.address)).reward.toString(), '0', "reward is correct")
        assert.equal((await staking.stakersLocked(acc2.address)).lastStakedTimestamp.toString(), _unstakeTimestamp.toString(), "lastStakedTimestamp is correct")
        assert.equal((await staking.stakeUnlocked(acc2.address)).toString(), '0', "stakeUnlocked is correct")
        assert.equal((await staking.getStakeLocked(acc2.address)).toString(), (12 - 1).toString(), "getStakeLocked is correct")

        await time.increase(7776000)
        assert.equal((await staking.stakeUnlocked(acc2.address)).toString(), "11", "stakeUnlocked is correct")

        const _balanceBeforeAcc2 = await ESE.balanceOf(acc2.address)
        const _stake = (await staking.earnedLocked(acc2.address)).add(11*20).add(11)
        await expect(staking.connect(acc2).unstakeLocked(11, acc2.address))
            .to.emit(staking, "UnstakeLocked")
            .withArgs(acc2.address, acc2.address, _stake)
        const __unstakeTimestamp = (await ethers.provider.getBlock()).timestamp
        const _balanceAfterAcc2  = await ESE.balanceOf(acc2.address)
        assert.equal((_balanceAfterAcc2.sub(_balanceBeforeAcc2)).toString(), _stake.toString(), "stake collected is correct")

        assert.equal((await staking.earnedLocked(acc2.address)).toString(), '0', "earned is correct")
        assert.equal((await staking.stakersLocked(acc2.address)).stake.toString(), '0', "stake is correct")
        assert.equal((await staking.stakersLocked(acc2.address)).reward.toString(), '0', "reward is correct")
        assert.equal((await staking.stakersLocked(acc2.address)).lastStakedTimestamp.toString(), __unstakeTimestamp.toString(), "lastStakedTimestamp is correct")
        assert.equal((await staking.stakeUnlocked(acc2.address)).toString(), '0', "stakeUnlocked is correct")
        assert.equal((await staking.getStakeLocked(acc2.address)).toString(), '0', "getStakeLocked is correct")
    })
    //todo: reverts if no tiers passed in constructor
    it('Admin', async () => {
        await expect(staking.connect(acc2).changeDuration(1)).to.be.revertedWith("Ownable: caller is not the owner")
        await expect(staking.connect(signer).changeDuration(1))
        .to.emit(staking, "ChangeDuration")
        .withArgs(90*24*60*60, 1)
        assert.equal(1, await staking.duration(), "duration has changed")
    })

    it('Ignore last breakpoint', async () => {
        await staking.connect(eesee).updateVolume(99999999999999, acc3.address)

        assert.equal((await staking.rewardRateFlexible(acc3.address)).toString(), ethers.utils.parseUnits('10', 'ether'), "Reward rate is correct")
        assert.equal((await staking.rewardRateLocked(acc3.address)).toString(), ethers.utils.parseUnits('20', 'ether'), "Reward rate is correct")
    })

    it('constructor fails', async () => {
        const _eeseeStaking = await hre.ethers.getContractFactory("eeseeStaking");
        await expect(_eeseeStaking.deploy(ESE.address, eesee.address, [])).to.be.revertedWith("eeseeStaking: Invalid tiers Length")
    })
});
