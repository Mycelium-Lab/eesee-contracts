const {
  time,
} = require('@nomicfoundation/hardhat-network-helpers')
const { expect } = require('chai')
const { ethers, network } = require('hardhat')
const assert = require('assert')
describe('eesee', function () {
  let ESE, mockPrivateCrowdsale
  let signer, acc2, acc3, acc4
  let balanceOfAcc2BeforeAllTransfers, balanceOfAcc3BeforeAllTransfers
  let timeNow
  let snapshotId
  this.beforeAll(async () => {
    [signer, acc2, acc3, acc4] = await ethers.getSigners()
    const _ESE = await hre.ethers.getContractFactory('ESE')
    const _mockPrivateCrowdsale = await hre.ethers.getContractFactory('TimedCrowdsale')
    ESE = await _ESE.deploy(ethers.utils.parseUnits('1000000', 'ether'))
    await ESE.deployed()
    await ESE.transfer(acc2.address, ethers.utils.parseUnits('30000', 'ether'))
    balanceOfAcc2BeforeAllTransfers = await ESE.balanceOf(acc2.address)
    balanceOfAcc3BeforeAllTransfers = await ESE.balanceOf(acc3.address)
    mockPrivateCrowdsale = await _mockPrivateCrowdsale.deploy()
    await mockPrivateCrowdsale.deployed()
  })
  it('Admin can set crowdsales', async () => {
    await expect(ESE.connect(acc2).setCrowdsales([signer.address], mockPrivateCrowdsale.address))
      .to.be.revertedWith('Ownable: caller is not the owner')
    await expect(ESE.connect(signer).setCrowdsales([signer.address, acc4.address], mockPrivateCrowdsale.address))
      .to.emit(ESE, 'SetCrowdsales')
      .withArgs([signer.address, acc4.address], mockPrivateCrowdsale.address)
    await expect(ESE.connect(signer).setCrowdsales([signer.address], mockPrivateCrowdsale.address))
      .to.be.revertedWith('ESE: crowdsales have already been set')
  })
  it('Crowdsale address can lock tokens', async () => {
    timeNow = (await ethers.provider.getBlock()).timestamp
    await expect(ESE.connect(acc2).lockTokens(acc2.address, ethers.utils.parseUnits('7000', 'ether'), timeNow + 86400 * 4))
      .to.be.revertedWith('ESE: only crowdsale contracts can lock tokens')
    await expect(ESE.connect(signer).lockTokens(acc2.address, ethers.utils.parseUnits('31000', 'ether'), timeNow + 86400 * 4))
      .to.be.revertedWith('ESE: unlocked tokens balance of recipient has to be lower or equal than amount')
    await expect(ESE.connect(signer).lockTokens(acc2.address, ethers.utils.parseUnits('1000', 'ether'), timeNow - 86400))
      .to.be.revertedWith('ESE: unlock time must be in the future')
    await expect(ESE.connect(signer).lockTokens(acc2.address, ethers.utils.parseUnits('500', 'ether'), timeNow + 86400))
      .to.emit(ESE, 'LockTokens')
      .withArgs(acc2.address, ethers.utils.parseUnits('500', 'ether').toString(), timeNow + 86400)
    await expect(ESE.connect(signer).lockTokens(acc2.address, ethers.utils.parseUnits('1500', 'ether'), timeNow + 86400 * 2))
      .to.emit(ESE, 'LockTokens')
      .withArgs(acc2.address, ethers.utils.parseUnits('1500', 'ether').toString(), timeNow + 86400 * 2)
    await expect(ESE.connect(signer).lockTokens(acc2.address, ethers.utils.parseUnits('3000', 'ether'), timeNow + 86400 * 3))
      .to.emit(ESE, 'LockTokens')
      .withArgs(acc2.address, ethers.utils.parseUnits('3000', 'ether').toString(), timeNow + 86400 * 3)
    await expect(ESE.connect(signer).lockTokens(acc2.address, ethers.utils.parseUnits('5000', 'ether'), timeNow + 86400 * 4))
      .to.emit(ESE, 'LockTokens')
      .withArgs(acc2.address, ethers.utils.parseUnits('5000', 'ether').toString(), timeNow + 86400 * 4)
    await expect(ESE.connect(signer).lockTokens(acc2.address, ethers.utils.parseUnits('10000', 'ether'), timeNow + 86400 * 5))
      .to.emit(ESE, 'LockTokens')
      .withArgs(acc2.address, ethers.utils.parseUnits('10000', 'ether').toString(), timeNow + 86400 * 5)
    const lockedTokensAmount = await ESE.lockedTokensAmount(acc2.address)
    assert.equal(lockedTokensAmount.toString(), ethers.utils.parseUnits('20000', 'ether'), 'lockedTokensAmount is correct')
    const lockedUserTokensLength = await ESE.getLockedUserTokensLength(acc2.address)
    assert.equal(lockedUserTokensLength.toString(), '5', 'Length of array of locked tokens structs is correct')
    const totalLockedTokensAmount = await ESE.getTotalLockedTokensAmount(acc2.address)
    assert.equal(totalLockedTokensAmount.toString(), ethers.utils.parseUnits('20000', 'ether'), 'totalLockedTokensAmount is correct')
  })
  it('Crowdsale address can lock tokens untill liquidity added', async () => {
    await expect(ESE.connect(acc2).lockPresaleLiquidityTokens(acc2.address, ethers.utils.parseUnits('1000', 'ether')))
      .to.be.revertedWith('ESE: only crowdsale contracts can lock tokens')
    await expect(ESE.connect(signer).lockPresaleLiquidityTokens(acc2.address, ethers.utils.parseUnits('11000', 'ether')))
      .to.be.revertedWith('ESE: unlocked tokens balance of recipient has to be lower or equal than amount')
    await expect(ESE.connect(signer).lockPresaleLiquidityTokens(acc2.address, ethers.utils.parseUnits('2500', 'ether')))
      .to.emit(ESE, 'LockPresaleLiquidityTokens')
      .withArgs(acc2.address, ethers.utils.parseUnits('2500', 'ether').toString())
    await expect(ESE.connect(signer).lockPresaleLiquidityTokens(acc2.address, ethers.utils.parseUnits('2500', 'ether')))
      .to.emit(ESE, 'LockPresaleLiquidityTokens')
      .withArgs(acc2.address, ethers.utils.parseUnits('2500', 'ether').toString())
    const totalLockedTokensAmount = await ESE.getTotalLockedTokensAmount(acc2.address)
    assert.equal(totalLockedTokensAmount.toString(), ethers.utils.parseUnits('25000', 'ether'), 'totalLockedTokensAmount is correct')
    const presaleLiquidityLockedTokens = await ESE.presaleLiquidityLockedTokens(acc2.address)
    assert.equal(presaleLiquidityLockedTokens.toString(), ethers.utils.parseUnits('5000', 'ether'), 'presaleLiquidityLockedTokens is correct')
  })
  it('Crowdsale address can lock tokens untill private round finished', async () => {
    await expect(ESE.connect(acc2).lockPresalePrivateTokens(acc2.address, ethers.utils.parseUnits('1000', 'ether')))
      .to.be.revertedWith('ESE: only crowdsale contracts can lock tokens')
    await expect(ESE.connect(signer).lockPresalePrivateTokens(acc2.address, ethers.utils.parseUnits('6000', 'ether')))
      .to.be.revertedWith('ESE: unlocked tokens balance of recipient has to be lower or equal than amount')
    await expect(ESE.connect(signer).lockPresalePrivateTokens(acc2.address, ethers.utils.parseUnits('2500', 'ether')))
      .to.emit(ESE, 'LockPresalePrivateTokens')
      .withArgs(acc2.address, ethers.utils.parseUnits('2500', 'ether').toString())
    await expect(ESE.connect(signer).lockPresalePrivateTokens(acc2.address, ethers.utils.parseUnits('2500', 'ether')))
      .to.emit(ESE, 'LockPresalePrivateTokens')
      .withArgs(acc2.address, ethers.utils.parseUnits('2500', 'ether').toString())
    let totalLockedTokensAmount = await ESE.getTotalLockedTokensAmount(acc2.address)
    assert.equal(totalLockedTokensAmount.toString(), ethers.utils.parseUnits('30000', 'ether'), 'totalLockedTokensAmount is correct')
    const presalePrivateLockedTokens = await ESE.presalePrivateLockedTokens(acc2.address)
    assert.equal(presalePrivateLockedTokens.toString(), ethers.utils.parseUnits('5000', 'ether'), 'presalePrivateLockedTokens is correct')
  })
  it('transfer() works correctly for multiple token locks', async () => {
    snapshotId = await network.provider.send('evm_snapshot')
    // Can't transfer locked tokens

    await expect(ESE.connect(acc2).transfer(acc3.address, ethers.utils.parseUnits('500', 'ether')))
      .to.be.revertedWith('ESE: not enough unlocked tokens')

    // Can transfer not locked tokens

    await ESE.transfer(acc2.address, ethers.utils.parseUnits('500', 'ether'))
    await expect(ESE.connect(acc2).transfer(acc4.address, ethers.utils.parseUnits('500', 'ether')))
      .to.emit(ESE, 'Transfer')
      .withArgs(acc2.address, acc4.address, ethers.utils.parseUnits('500', 'ether'))
    
    // 3 days in, 500 + 1500 + 3000 locked tokens unlocked in 3 different locks

    await time.increase(86405 * 3)
    const balanceOfAcc2BeforeTransfers = await ESE.balanceOf(acc2.address)
    const balanceOfAcc3BeforeTransfers = await ESE.balanceOf(acc3.address)
    let tokensAvailableForUnlock = await ESE.getTokensAvailableForUnlock(acc2.address)
    assert.equal(tokensAvailableForUnlock.toString(), ethers.utils.parseUnits('5000', 'ether'), 'tokensAvailableForUnlock is correct')
    await expect(ESE.connect(acc2).transfer(acc3.address, ethers.utils.parseUnits('5001', 'ether')))
      .to.be.revertedWith('ESE: not enough unlocked tokens')
    await expect(ESE.connect(acc2).transfer(acc3.address, ethers.utils.parseUnits('500', 'ether')))
      .to.emit(ESE, 'Transfer')
      .withArgs(acc2.address, acc3.address, ethers.utils.parseUnits('500', 'ether'))
    const lockedUserTokensLength = await ESE.getLockedUserTokensLength(acc2.address)
    assert.equal(lockedUserTokensLength.toString(), '2', 'Length of array of locked tokens structs is correct')
    const totalLockedTokensAmount = await ESE.getTotalLockedTokensAmount(acc2.address)
    const lockedTokensAmount = await ESE.lockedTokensAmount(acc2.address)
    assert.equal(lockedTokensAmount.toString(), ethers.utils.parseUnits('15000', 'ether'), 'lockedTokensAmount is correct')
    assert.equal(totalLockedTokensAmount.toString(), ethers.utils.parseUnits('25000', 'ether'), 'totalLockedTokensAmount is correct')
    await expect(ESE.connect(acc2).transfer(acc3.address, ethers.utils.parseUnits('4500', 'ether')))
      .to.emit(ESE, 'Transfer')
      .withArgs(acc2.address, acc3.address, ethers.utils.parseUnits('4500', 'ether'))
    const balanceOfAcc2AfterTransfers = await ESE.balanceOf(acc2.address)
    const balanceOfAcc3AfterTransfers = await ESE.balanceOf(acc3.address)
    assert.equal(balanceOfAcc2BeforeTransfers.sub(ethers.utils.parseUnits('5000', 'ether')).toString(), balanceOfAcc2AfterTransfers.toString(), 'balanceOf acc2 is correct')
    assert.equal(balanceOfAcc3BeforeTransfers.add(ethers.utils.parseUnits('5000', 'ether')).toString(), balanceOfAcc3AfterTransfers.toString(), 'balanceOf acc3 is correct')
  })
  it('transfer() works correctly for private round token lock', async () => {
    // 4 days in, 5000 locked tokens unlocked + private sale finished

    await time.increase(86405)
    const balanceOfAcc2BeforeTransfers = await ESE.balanceOf(acc2.address)
    const balanceOfAcc3BeforeTransfers = await ESE.balanceOf(acc3.address)
    let tokensAvailableForUnlock = await ESE.getTokensAvailableForUnlock(acc2.address)
    assert.equal(tokensAvailableForUnlock.toString(), ethers.utils.parseUnits('5000', 'ether'), 'tokensAvailableForUnlock is correct')
    await expect(ESE.connect(acc2).transfer(acc3.address, ethers.utils.parseUnits('5001', 'ether')))
      .to.be.revertedWith('ESE: not enough unlocked tokens')
    await mockPrivateCrowdsale.setHasClosed(true)
    tokensAvailableForUnlock = await ESE.getTokensAvailableForUnlock(acc2.address)
    assert.equal(tokensAvailableForUnlock.toString(), ethers.utils.parseUnits('10000', 'ether'), 'tokensAvailableForUnlock is correct')
    await expect(ESE.connect(acc2).transfer(acc3.address, ethers.utils.parseUnits('10000', 'ether')))
      .to.emit(ESE, 'Transfer')
      .withArgs(acc2.address, acc3.address, ethers.utils.parseUnits('10000', 'ether'))
    const lockedUserTokensLength = await ESE.getLockedUserTokensLength(acc2.address)
    assert.equal(lockedUserTokensLength.toString(), '1', 'Length of array of locked tokens structs is correct')
    const presalePrivateLockedTokens = await ESE.presalePrivateLockedTokens(acc2.address)
    assert.equal(presalePrivateLockedTokens.toString(), '0', 'presalePrivateLockedTokens is correct')
    const balanceOfAcc2AfterTransfers = await ESE.balanceOf(acc2.address)
    const balanceOfAcc3AfterTransfers = await ESE.balanceOf(acc3.address)
    assert.equal(balanceOfAcc2BeforeTransfers.sub(ethers.utils.parseUnits('10000', 'ether')).toString(), balanceOfAcc2AfterTransfers.toString(), 'balanceOf acc2 is correct')
    assert.equal(balanceOfAcc3BeforeTransfers.add(ethers.utils.parseUnits('10000', 'ether')).toString(), balanceOfAcc3AfterTransfers.toString(), 'balanceOf acc3 is correct')
  })
  it('Admin can unlock liquidity locked tokens', async () => {
    await expect(ESE.connect(acc2).unlockPresaleLiquidityTokens())
    .to.be.revertedWith('Ownable: caller is not the owner')
    const unlockTx = await ESE.connect(signer).unlockPresaleLiquidityTokens()
    const unlockReceipt = await unlockTx.wait()
    const expectedUnlockTimestamp = (await ethers.provider.getBlock(unlockReceipt.blockNumber)).timestamp + 86400 * 180
    let eventTimestamp = 0
    let didEventEmit = false
    unlockReceipt.events.forEach((event) => {
      if(event.event === 'PresaleLiquidityTokensUnlock') {
        didEventEmit = true
        eventTimestamp = event.args.timestamp
      }
    })
    assert.equal(didEventEmit, true, 'PresaleLiquidityTokensUnlock event emitted' )
    assert.equal(expectedUnlockTimestamp.toString(), eventTimestamp.toString(), 'Unlock timestamp is correct')
    await expect(ESE.connect(signer).unlockPresaleLiquidityTokens())
      .to.be.revertedWith('ESE: you have already unlocked tokens after liquidity had been added')
  })
  it('transfer() works correctly for liquidity token lock', async () => {
    // 180 days have passed, 10000 locked tokens from lockTokens, 5000 from presale liqudity
    const balanceOfAcc2BeforeTransfers = await ESE.balanceOf(acc2.address)
    const balanceOfAcc3BeforeTransfers = await ESE.balanceOf(acc3.address)
    let tokensAvailableForUnlock = await ESE.getTokensAvailableForUnlock(acc2.address)
    assert.equal(tokensAvailableForUnlock.toString(), ethers.utils.parseUnits('0', 'ether'), 'tokensAvailableForUnlock is correct')
    await time.increase(86400 * 180)
    tokensAvailableForUnlock = await ESE.getTokensAvailableForUnlock(acc2.address)
    assert.equal(tokensAvailableForUnlock.toString(), ethers.utils.parseUnits('15000', 'ether'), 'tokensAvailableForUnlock is correct')
    await expect(ESE.connect(acc2).transfer(acc3.address, ethers.utils.parseUnits('15000', 'ether')))
      .to.emit(ESE, 'Transfer')
      .withArgs(acc2.address, acc3.address, ethers.utils.parseUnits('15000', 'ether'))
    const lockedUserTokensLength = await ESE.getLockedUserTokensLength(acc2.address)
    assert.equal(lockedUserTokensLength.toString(), '0', 'Length of array of locked tokens structs is correct')
    const lockedTokensAmount = await ESE.lockedTokensAmount(acc2.address)
    assert.equal(lockedTokensAmount.toString(), ethers.utils.parseUnits('0', 'ether'), 'lockedTokensAmount is correct')
    const presaleLiquidityLockedTokens = await ESE.presaleLiquidityLockedTokens(acc2.address)
    assert.equal(presaleLiquidityLockedTokens.toString(), ethers.utils.parseUnits('0', 'ether'), 'presaleLiquidityLockedTokens is correct')
    const balanceOfAcc2AfterTransfers = await ESE.balanceOf(acc2.address)
    const balanceOfAcc3AfterTransfers = await ESE.balanceOf(acc3.address)
    assert.equal(balanceOfAcc2BeforeTransfers.sub(ethers.utils.parseUnits('15000', 'ether')).toString(), balanceOfAcc2AfterTransfers.toString(), 'balanceOf acc2 is correct')
    assert.equal(balanceOfAcc3BeforeTransfers.add(ethers.utils.parseUnits('15000', 'ether')).toString(), balanceOfAcc3AfterTransfers.toString(), 'balanceOf acc3 is correct')
  })
  it('Balances of acc2 and acc3 after all transfer() are correct', async () => {
    const balanceOfAcc2AfterAllTransfers = await ESE.balanceOf(acc2.address)
    const balanceOfAcc3AfterAllTransfers = await ESE.balanceOf(acc3.address)
    assert.equal(balanceOfAcc2AfterAllTransfers.toString(), '0', 'Balance of acc2 is correct')
    assert.equal(balanceOfAcc3AfterAllTransfers.toString(), balanceOfAcc3BeforeAllTransfers.add(balanceOfAcc2BeforeAllTransfers).toString(), 'Balance of acc3 is correct')
  })
  
  it('transferFrom() works correctly for multiple token locks', async () => {
    // Come back to snapshot before transfers 
    await network.provider.send('evm_revert', [snapshotId])
    balanceOfAcc2BeforeAllTransfers = await ESE.balanceOf(acc2.address)
    balanceOfAcc3BeforeAllTransfers = await ESE.balanceOf(acc3.address)
    await ESE.connect(acc2).approve(signer.address, ethers.utils.parseUnits('30500', 'ether'))
    // Can't transfer locked tokens

    await expect(ESE.connect(acc2).transferFrom(acc2.address, acc3.address, ethers.utils.parseUnits('500', 'ether')))
      .to.be.revertedWith('ESE: not enough unlocked tokens')

    // Can transfer not locked tokens

    await ESE.transfer(acc2.address, ethers.utils.parseUnits('500', 'ether'))
    await expect(ESE.connect(signer).transferFrom(acc2.address, acc4.address, ethers.utils.parseUnits('500', 'ether')))
      .to.emit(ESE, 'Transfer')
      .withArgs(acc2.address, acc4.address, ethers.utils.parseUnits('500', 'ether'))
    
    // 3 days in, 500 + 1500 + 3000 locked tokens unlocked in 3 different locks

    await time.increase(86405 * 3)
    const balanceOfAcc2BeforeTransfers = await ESE.balanceOf(acc2.address)
    const balanceOfAcc3BeforeTransfers = await ESE.balanceOf(acc3.address)
    let tokensAvailableForUnlock = await ESE.getTokensAvailableForUnlock(acc2.address)
    assert.equal(tokensAvailableForUnlock.toString(), ethers.utils.parseUnits('5000', 'ether'), 'tokensAvailableForUnlock is correct')
    await expect(ESE.connect(signer).transferFrom(acc2.address, acc3.address, ethers.utils.parseUnits('5001', 'ether')))
      .to.be.revertedWith('ESE: not enough unlocked tokens')
    await expect(ESE.connect(signer).transferFrom(acc2.address, acc3.address, ethers.utils.parseUnits('500', 'ether')))
      .to.emit(ESE, 'Transfer')
      .withArgs(acc2.address, acc3.address, ethers.utils.parseUnits('500', 'ether'))
    const lockedUserTokensLength = await ESE.getLockedUserTokensLength(acc2.address)
    assert.equal(lockedUserTokensLength.toString(), '2', 'Length of array of locked tokens structs is correct')
    const totalLockedTokensAmount = await ESE.getTotalLockedTokensAmount(acc2.address)
    const lockedTokensAmount = await ESE.lockedTokensAmount(acc2.address)
    assert.equal(lockedTokensAmount.toString(), ethers.utils.parseUnits('15000', 'ether'), 'lockedTokensAmount is correct')
    assert.equal(totalLockedTokensAmount.toString(), ethers.utils.parseUnits('25000', 'ether'), 'totalLockedTokensAmount is correct')
    await expect(ESE.connect(signer).transferFrom(acc2.address, acc3.address, ethers.utils.parseUnits('4500', 'ether')))
      .to.emit(ESE, 'Transfer')
      .withArgs(acc2.address, acc3.address, ethers.utils.parseUnits('4500', 'ether'))
    const balanceOfAcc2AfterTransfers = await ESE.balanceOf(acc2.address)
    const balanceOfAcc3AfterTransfers = await ESE.balanceOf(acc3.address)
    assert.equal(balanceOfAcc2BeforeTransfers.sub(ethers.utils.parseUnits('5000', 'ether')).toString(), balanceOfAcc2AfterTransfers.toString(), 'balanceOf acc2 is correct')
    assert.equal(balanceOfAcc3BeforeTransfers.add(ethers.utils.parseUnits('5000', 'ether')).toString(), balanceOfAcc3AfterTransfers.toString(), 'balanceOf acc3 is correct')
  })
  it('transferFrom() works correctly for private round token lock', async () => {
    // 4 days in, 5000 locked tokens unlocked + private sale finished

    await time.increase(86405)
    const balanceOfAcc2BeforeTransfers = await ESE.balanceOf(acc2.address)
    const balanceOfAcc3BeforeTransfers = await ESE.balanceOf(acc3.address)
    let tokensAvailableForUnlock = await ESE.getTokensAvailableForUnlock(acc2.address)
    assert.equal(tokensAvailableForUnlock.toString(), ethers.utils.parseUnits('5000', 'ether'), 'tokensAvailableForUnlock is correct')
    await expect(ESE.connect(signer).transferFrom(acc2.address, acc3.address, ethers.utils.parseUnits('5001', 'ether')))
      .to.be.revertedWith('ESE: not enough unlocked tokens')
    await mockPrivateCrowdsale.setHasClosed(true)
    tokensAvailableForUnlock = await ESE.getTokensAvailableForUnlock(acc2.address)
    assert.equal(tokensAvailableForUnlock.toString(), ethers.utils.parseUnits('10000', 'ether'), 'tokensAvailableForUnlock is correct')
    await expect(ESE.connect(signer).transferFrom(acc2.address,acc3.address, ethers.utils.parseUnits('10000', 'ether')))
      .to.emit(ESE, 'Transfer')
      .withArgs(acc2.address, acc3.address, ethers.utils.parseUnits('10000', 'ether'))
    const lockedUserTokensLength = await ESE.getLockedUserTokensLength(acc2.address)
    assert.equal(lockedUserTokensLength.toString(), '1', 'Length of array of locked tokens structs is correct')
    const presalePrivateLockedTokens = await ESE.presalePrivateLockedTokens(acc2.address)
    assert.equal(presalePrivateLockedTokens.toString(), '0', 'presalePrivateLockedTokens is correct')
    const balanceOfAcc2AfterTransfers = await ESE.balanceOf(acc2.address)
    const balanceOfAcc3AfterTransfers = await ESE.balanceOf(acc3.address)
    assert.equal(balanceOfAcc2BeforeTransfers.sub(ethers.utils.parseUnits('10000', 'ether')).toString(), balanceOfAcc2AfterTransfers.toString(), 'balanceOf acc2 is correct')
    assert.equal(balanceOfAcc3BeforeTransfers.add(ethers.utils.parseUnits('10000', 'ether')).toString(), balanceOfAcc3AfterTransfers.toString(), 'balanceOf acc3 is correct')
  })
  it('transferFrom() works correctly for liquidity token lock', async () => {
    // 180 days have passed, 10000 locked tokens from lockTokens, 5000 from presale liqudity
    await ESE.connect(signer).unlockPresaleLiquidityTokens()
    const balanceOfAcc2BeforeTransfers = await ESE.balanceOf(acc2.address)
    const balanceOfAcc3BeforeTransfers = await ESE.balanceOf(acc3.address)
    let tokensAvailableForUnlock = await ESE.getTokensAvailableForUnlock(acc2.address)
    assert.equal(tokensAvailableForUnlock.toString(), ethers.utils.parseUnits('0', 'ether'), 'tokensAvailableForUnlock is correct')
    await time.increase(86400 * 180)
    tokensAvailableForUnlock = await ESE.getTokensAvailableForUnlock(acc2.address)
    assert.equal(tokensAvailableForUnlock.toString(), ethers.utils.parseUnits('15000', 'ether'), 'tokensAvailableForUnlock is correct')
    await expect(ESE.connect(signer).transferFrom(acc2.address, acc3.address, ethers.utils.parseUnits('15000', 'ether')))
      .to.emit(ESE, 'Transfer')
      .withArgs(acc2.address, acc3.address, ethers.utils.parseUnits('15000', 'ether'))
    const lockedUserTokensLength = await ESE.getLockedUserTokensLength(acc2.address)
    assert.equal(lockedUserTokensLength.toString(), '0', 'Length of array of locked tokens structs is correct')
    const lockedTokensAmount = await ESE.lockedTokensAmount(acc2.address)
    assert.equal(lockedTokensAmount.toString(), ethers.utils.parseUnits('0', 'ether'), 'lockedTokensAmount is correct')
    const presaleLiquidityLockedTokens = await ESE.presaleLiquidityLockedTokens(acc2.address)
    assert.equal(presaleLiquidityLockedTokens.toString(), ethers.utils.parseUnits('0', 'ether'), 'presaleLiquidityLockedTokens is correct')
    const balanceOfAcc2AfterTransfers = await ESE.balanceOf(acc2.address)
    const balanceOfAcc3AfterTransfers = await ESE.balanceOf(acc3.address)
    assert.equal(balanceOfAcc2BeforeTransfers.sub(ethers.utils.parseUnits('15000', 'ether')).toString(), balanceOfAcc2AfterTransfers.toString(), 'balanceOf acc2 is correct')
    assert.equal(balanceOfAcc3BeforeTransfers.add(ethers.utils.parseUnits('15000', 'ether')).toString(), balanceOfAcc3AfterTransfers.toString(), 'balanceOf acc3 is correct')
  })
  it('Balances of acc2 and acc3 after all transferFrom() are correct', async () => {
    const balanceOfAcc2AfterAllTransfers = await ESE.balanceOf(acc2.address)
    const balanceOfAcc3AfterAllTransfers = await ESE.balanceOf(acc3.address)
    assert.equal(balanceOfAcc2AfterAllTransfers.toString(), '0', 'Balance of acc2 is correct')
    assert.equal(balanceOfAcc3AfterAllTransfers.toString(), balanceOfAcc3BeforeAllTransfers.add(balanceOfAcc2BeforeAllTransfers).toString(), 'Balance of acc3 is correct')
  })
})