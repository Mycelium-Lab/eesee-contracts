const {
    time,
  } = require('@nomicfoundation/hardhat-network-helpers')
  const { expect } = require('chai')
  const { ethers, network } = require('hardhat')
  const { StandardMerkleTree } = require('@openzeppelin/merkle-tree')
  const assert = require('assert')
  describe('eesee', function () {
    let ESE, privateCrowdsale, presaleCrowdsale
    let signer, acc2, acc3, acc4
    let balanceOfAcc2BeforeAllTransfers, balanceOfAcc3BeforeAllTransfers
    let timeNow
    let merkleTree
    let leaves = []
    let buyTokensTimestamp
    const getProof = (tree, address) => {
      let proof = null
      for (const [i, v] of tree.entries()) {
          if (v[0] === address) {
              proof = tree.getProof(i);
            }
      }
      return proof
  }
    this.beforeAll(async () => {
      [signer, acc2, acc3, acc4] = await ethers.getSigners()
      const _ESE = await hre.ethers.getContractFactory('ESE')
      const _private = await hre.ethers.getContractFactory('PrivateSale')
      const _presale = await hre.ethers.getContractFactory('Presale')
      ESE = await _ESE.deploy(ethers.utils.parseUnits('1000000', 'ether'))
      await ESE.deployed()
      await ESE.transfer(acc2.address, ethers.utils.parseUnits('30000', 'ether'))
 
      balanceOfAcc2BeforeAllTransfers = await ESE.balanceOf(acc2.address)
      balanceOfAcc3BeforeAllTransfers = await ESE.balanceOf(acc3.address)
      
      leaves.push([acc2.address])
      merkleTree = StandardMerkleTree.of(leaves, ['address'])
      timeNow = (await ethers.provider.getBlock()).timestamp
      privateCrowdsale = await _private.deploy(
        '100000', 
        acc4.address, 
        ESE.address, 
        ethers.utils.parseUnits('0.0001', 'ether'), // min purchase amount is 10 ESE or 0.0001 ETH
        ethers.utils.parseUnits('0.001', 'ether'), // cap is 100 ESE or 0.001 ETH
        timeNow + 86400,
        timeNow + 86400 * 2,
        merkleTree.root
        )
    
      presaleCrowdsale = await _presale.deploy(
        '100000', // 1 ESE = 0.00001 ETH
        acc4.address, 
        ESE.address, 
        ethers.utils.parseUnits('0.0001', 'ether'), // min purchase amount is 10 ESE or 0.0001 ETH
        ethers.utils.parseUnits('0.001', 'ether'), // cap is 100 ESE or 0.001 ETH
        timeNow + 86400,
        timeNow + 86400 * 2,
        merkleTree.root
        )
      await privateCrowdsale.deployed()
      await presaleCrowdsale.deployed()
    await ESE.transfer(privateCrowdsale.address, ethers.utils.parseUnits('1000', 'ether'))
    await ESE.setCrowdsales([presaleCrowdsale.address], privateCrowdsale.address)
    })
    it('Can\'t buy tokens before opening time', async () => {
      await expect(privateCrowdsale.connect(acc2).buyTokens(acc2.address, getProof(merkleTree, acc2.address), {value: ethers.utils.parseEther('1.0')}))
      .to.be.revertedWith('TimedCrowdsale: not open')
    })
    it('Can\'t buy tokens less than minimum', async () => {
      await time.increase(86401)
      await expect(privateCrowdsale.connect(acc2).buyTokens(acc2.address, getProof(merkleTree, acc2.address), {value: ethers.utils.parseEther('0.00001')}))
      .to.be.revertedWith('Crowdsale: you can\'t buy less than minimum purchase amount.')
    })
    it('Can\'t buy tokens if not in whitelist', async () => {
      await expect(privateCrowdsale.connect(signer).buyTokens(signer.address, getProof(merkleTree, acc2.address), {value: ethers.utils.parseEther('0.001')}))
      .to.be.revertedWith('Crowdsale: beneficiary address is not in the whitelist')
    })
    it('Can buy tokens', async () => {
      const balanceBefore = await ESE.balanceOf(acc2.address)
      await expect(privateCrowdsale.connect(acc2).buyTokens(acc2.address, getProof(merkleTree, acc2.address), {value: ethers.utils.parseEther('0.0001')}))
        .to.emit(privateCrowdsale, 'TokensPurchased')
        .withArgs(acc2.address, acc2.address, ethers.utils.parseEther('0.0001'), ethers.utils.parseEther('10'))
      buyTokensTimestamp = (await ethers.provider.getBlock()).timestamp
      const balanceAfter = await ESE.balanceOf(acc2.address)
      assert.equal(balanceBefore.add(ethers.utils.parseUnits('10', 'ether')).toString(), balanceAfter.toString(), 'Token balance after purchase is correct')
    })
    it('Can\'t buy more than cap', async () => {
      await expect(privateCrowdsale.connect(acc2).buyTokens(acc2.address, getProof(merkleTree, acc2.address), {value: ethers.utils.parseEther('0.00091')}))
        .to.be.revertedWith('CappedCrowdsale: cap exceeded')
    })
    it('Tokens locked correctly after purchase', async () => {
      const lockedTokensAmount = await ESE.lockedTokensAmount(acc2.address)
      const lockedTokensLength = await ESE.getLockedUserTokensLength(acc2.address)
      assert.equal(lockedTokensAmount.toString(), ethers.utils.parseEther('10').toString(), 'lockedTokensAmount is correct')
      assert.equal(lockedTokensLength.toString(), '10', 'Locked user tokens length is correct.')
      for(let i = 0; i < lockedTokensLength; i ++) {
        const lockedTokens = await ESE.getLockedUserTokens(acc2.address, i)
        assert.equal(lockedTokens.amount.toString(), ethers.utils.parseEther('1').toString(), `lockedTokens[${i}] amount is correct`)
        assert.equal(lockedTokens.unlockTimestamp.toString(), (buyTokensTimestamp + (i+1) * 86400 * 60) + '', `lockedTokens[${i}] unlockTimestamp is correct`)
      }
    })
    it('Can\'t buy tokens before after closing time', async () => {
      await time.increase(86401)
      await expect(presaleCrowdsale.connect(acc2).buyTokens(acc2.address, getProof(merkleTree, acc2.address), {value: ethers.utils.parseEther('1.0')}))
      .to.be.revertedWith('TimedCrowdsale: not open')
    })
  })
  