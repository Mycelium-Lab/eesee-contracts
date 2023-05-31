const {
  time,
} = require('@nomicfoundation/hardhat-network-helpers')
const { expect } = require('chai')
const { ethers, network } = require('hardhat')
const assert = require('assert')
describe('eesee', function () {
  let ESE, mockPrivateSale, mockPresale
  let signer, acc2, acc3, acc4, acc5, acc6
  let snapshotId, snapshotId2, snapshotId3
  this.beforeAll(async () => {
    [signer, acc2, acc3, acc4, acc5, acc6] = await ethers.getSigners()
    const _ESE = await hre.ethers.getContractFactory('ESE')
    const _mockPrivateSale = await hre.ethers.getContractFactory('MockESECrowdsale')

    mockPresale = await _mockPrivateSale.deploy()
    await mockPresale.deployed()
    mockPrivateSale = await _mockPrivateSale.deploy()
    await mockPrivateSale.deployed()

    ESE = await _ESE.deploy(
      ethers.utils.parseUnits('1000000', 'ether'), 
      ethers.utils.parseUnits('30000', 'ether'), 
      mockPresale.address, 
      31536000, 
      ethers.utils.parseUnits('30000', 'ether'), 
      mockPrivateSale.address, 
      10, 
      5184000
    )
    await ESE.deployed()
    await ESE.transfer(acc2.address, ethers.utils.parseUnits('30000', 'ether'))
    balanceOfAcc2BeforeAllTransfers = await ESE.balanceOf(acc2.address)
    balanceOfAcc3BeforeAllTransfers = await ESE.balanceOf(acc3.address)
  })
  it('Init is correct', async () => {
    assert.equal(await ESE.presale(), mockPresale.address, 'mockPresale is correct')
    assert.equal(await ESE.presaleUnlockTime(), 31536000, 'mockPrivateSale is correct')

    assert.equal(await ESE.privateSale(), mockPrivateSale.address, 'mockPrivateSale is correct')
    assert.equal(await ESE.privateSalePeriods(), 10, 'mockPrivateSale is correct')
    assert.equal(await ESE.privateSalePeriodTime(), 5184000, 'mockPrivateSale is correct')

    assert.equal(await ESE.lockPrivateSale(), true, 'mockPrivateSale is correct')
  })
  it('Presale address can lock tokens', async () => {
    snapshotId = await network.provider.send('evm_snapshot')

    await mockPresale.connect(acc2).transfer(ESE.address, acc4.address, '100000')
    //also transfer from acc2 to have an idea on how lockedAmount changed
    await ESE.connect(acc2).transfer(acc4.address, '100000')

    assert.equal((await ESE.lockedAmount(acc4.address)).toString(), '50000', 'Locked amount is correct')
    assert.equal((await ESE.available(acc4.address)).toString(), '150000', 'Available amount is correct')

    await time.increase(31536000)

    assert.equal((await ESE.lockedAmount(acc4.address)).toString(), '0', 'Locked amount is correct')
    assert.equal((await ESE.available(acc4.address)).toString(), '200000', 'Available amount is correct')
  })

  it('Private sale address can lock tokens', async () => {
    await network.provider.send('evm_revert', [snapshotId])
    snapshotId2 = await network.provider.send('evm_snapshot')
    await mockPrivateSale.connect(acc2).transfer(ESE.address, acc4.address, '100000')
    //also transfer from acc2 to have an idea on how lockedAmount changed
    await ESE.connect(acc2).transfer(acc4.address, '100000')

    assert.equal((await ESE.lockedAmount(acc4.address)).toString(), '100000', 'Locked amount is correct')
    assert.equal((await ESE.available(acc4.address)).toString(), '100000', 'Available amount is correct')

    for(let i = 1; i < 11; i ++) {
      await time.increase(5184000)
      assert.equal((await ESE.lockedAmount(acc4.address)).toString(), (100000 * (10 - i) / 10).toString(), 'Locked amount is correct')
      assert.equal((await ESE.available(acc4.address)).toString(), (100000 + 100000 * i / 10).toString(), 'Available amount is correct')
    }

    assert.equal((await ESE.lockedAmount(acc4.address)).toString(), '0', 'Locked amount is correct')
    assert.equal((await ESE.available(acc4.address)).toString(), '200000', 'Available amount is correct')
  })

  it('Both locks can be active', async () => {
    await network.provider.send('evm_revert', [snapshotId2])
    snapshotId3 = await network.provider.send('evm_snapshot')
    await mockPresale.connect(acc2).transfer(ESE.address, acc4.address, '100000')
    await mockPrivateSale.connect(acc2).transfer(ESE.address, acc4.address, '100000')
    //also transfer from acc2 to have an idea on how lockedAmount changed
    await ESE.connect(acc2).transfer(acc4.address, '100000')

    assert.equal((await ESE.lockedAmount(acc4.address)).toString(), '150000', 'Locked amount is correct')
    assert.equal((await ESE.available(acc4.address)).toString(), '150000', 'Available amount is correct')

    for(let i = 1; i < 11; i ++) {
      await time.increase(5184000)
      if(5184000*i >= 31536000){
        assert.equal((await ESE.lockedAmount(acc4.address)).toString(), (100000 * (10 - i) / 10).toString(), 'Locked amount is correct')
        assert.equal((await ESE.available(acc4.address)).toString(), (200000 + 100000 * i / 10).toString(), 'Available amount is correct')
      } else {
        assert.equal((await ESE.lockedAmount(acc4.address)).toString(), (50000 + 100000 * (10 - i) / 10).toString(), 'Locked amount is correct')
        assert.equal((await ESE.available(acc4.address)).toString(), (150000 + 100000 * i / 10).toString(), 'Available amount is correct')
      }
    }
    assert.equal((await ESE.lockedAmount(acc4.address)).toString(), '0', 'Locked amount is correct')
    assert.equal((await ESE.available(acc4.address)).toString(), '300000', 'Available amount is correct')
  })
  it('transfer() works correctly for multiple token locks', async () => {
    await network.provider.send('evm_revert', [snapshotId3])
    await mockPresale.connect(acc2).transfer(ESE.address, acc4.address, '100000')
    // Can't transfer locked tokens

    await expect(ESE.connect(acc4).transfer(acc5.address, '100000'))
      .to.be.revertedWithCustomError(ESE, 'TransferingLockedTokens')
      .withArgs('50000')

    // Can transfer not locked tokens

    await expect(ESE.connect(acc4).transfer(acc5.address, '50000'))
      .to.emit(ESE, 'Transfer')
      .withArgs(acc4.address, acc5.address, '50000')/

    await expect(ESE.connect(acc4).transfer(acc5.address, '50000'))
      .to.be.revertedWithCustomError(ESE, 'TransferingLockedTokens')
      .withArgs('50000')

    await time.increase(31536000)

    await expect(ESE.connect(acc4).transfer(acc5.address, '50000'))
      .to.emit(ESE, 'Transfer')
      .withArgs(acc4.address, acc5.address, '50000')
  })
})