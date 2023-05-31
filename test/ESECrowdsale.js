const {
    time,
  } = require('@nomicfoundation/hardhat-network-helpers')
  const { getContractAddress } = require('@ethersproject/address')
  const { expect } = require('chai')
  const { ethers, network } = require('hardhat')
  const { StandardMerkleTree } = require('@openzeppelin/merkle-tree')
  const assert = require('assert')
  describe('ESECrowdsale', function () {
    let ESE, MockERC20, privateCrowdsale, presaleCrowdsale
    let signer, acc2, acc3, acc4
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
  const zeroAddress = "0x0000000000000000000000000000000000000000"
    this.beforeAll(async () => {
      [signer, acc2, acc3, acc4] = await ethers.getSigners()
      const _ESE = await hre.ethers.getContractFactory('ESE')
      const _crowdsale = await hre.ethers.getContractFactory('ESECrowdsale')
      const _MockERC20 = await hre.ethers.getContractFactory('MockERC20')

      MockERC20 = await _MockERC20.deploy(ethers.utils.parseUnits('1000000', 'ether'))
      
      leaves.push([acc2.address])
      merkleTree = StandardMerkleTree.of(leaves, ['address'])
      timeNow = (await ethers.provider.getBlock()).timestamp

      const [owner] = await ethers.getSigners()

      const transactionCount = await owner.getTransactionCount()
      const futureESEAddress = getContractAddress({
        from: owner.address,
        nonce: transactionCount+2
      })

      privateCrowdsale = await _crowdsale.deploy(
        '100000', 
        acc4.address, 
        futureESEAddress, 
        MockERC20.address,
        ethers.utils.parseUnits('100', 'ether'), 
        ethers.utils.parseUnits('1000', 'ether'),
        timeNow + 86400,
        timeNow + 2*86400,
        merkleTree.root
      )
    
      presaleCrowdsale = await _crowdsale.deploy(
        '100000', // 1 ESE = 0.00001 ERC20
        acc4.address, 
        futureESEAddress, 
        MockERC20.address,
        ethers.utils.parseUnits('10', 'ether'), // min purchase amount is 10 ESE 
        ethers.utils.parseUnits('100', 'ether'), // cap is 100 ESE 
        timeNow + 86400,
        timeNow + 2*86400,
        merkleTree.root
      )
      await privateCrowdsale.deployed()
      await presaleCrowdsale.deployed()
      ESE = await _ESE.deploy(
        ethers.utils.parseUnits('1000000', 'ether'), 
        ethers.utils.parseUnits('1000', 'ether'), 
        presaleCrowdsale.address, 
        31536000, 
        ethers.utils.parseUnits('1000', 'ether'), 
        privateCrowdsale.address, 
        10, 
        5184000
      )
      
      await ESE.deployed()
      await MockERC20.transfer(acc2.address, ethers.utils.parseUnits('30000', 'ether'))
    })
    it('Can\'t buy tokens before opening time', async () => {
      await expect(presaleCrowdsale.connect(acc2).buyESE(acc2.address, ethers.utils.parseEther('10'), getProof(merkleTree, acc2.address)))
      .to.be.revertedWithCustomError(presaleCrowdsale, 'NotOpen')
    })
    it('Can\'t buy tokens less than minimum', async () => {
      await time.increase(86401)
      await expect(presaleCrowdsale.connect(acc2).buyESE(acc2.address, ethers.utils.parseEther('9'), getProof(merkleTree, acc2.address)))
      .to.be.revertedWithCustomError(presaleCrowdsale, 'SellAmountTooLow')
    })
    it('Can\'t buy tokens more than than maximum', async () => {
      await expect(presaleCrowdsale.connect(acc2).buyESE(acc2.address, ethers.utils.parseUnits('101', 'ether'), getProof(merkleTree, acc2.address)))
      .to.be.revertedWithCustomError(presaleCrowdsale, 'SellAmountTooHigh')
    })
    it('Can\'t buy tokens if not in whitelist', async () => {
      await expect(presaleCrowdsale.connect(signer).buyESE(acc2.address, ethers.utils.parseEther('10'), getProof(merkleTree, acc2.address)))
      .to.be.revertedWithCustomError(presaleCrowdsale, 'NotWhitelisted')
    })
    it('Can\'t send to zero address', async () => {
      await expect(presaleCrowdsale.connect(acc2).buyESE(zeroAddress, ethers.utils.parseEther('10'), getProof(merkleTree, acc2.address)))
      .to.be.revertedWithCustomError(presaleCrowdsale, 'InvalidBeneficiary')
    })

    
    it('Can buy tokens', async () => {
      const balanceBefore = await ESE.balanceOf(acc2.address)
      const _balanceBefore = await MockERC20.balanceOf(acc2.address)
      const __balanceBefore = await MockERC20.balanceOf(acc4.address)
      await MockERC20.connect(acc2).approve(presaleCrowdsale.address, ethers.utils.parseEther('10'))
      await expect(presaleCrowdsale.connect(acc2).buyESE(acc2.address, ethers.utils.parseEther('10'), getProof(merkleTree, acc2.address)))
        .to.emit(presaleCrowdsale, 'TokensPurchased')
        .withArgs(acc2.address, acc2.address, ethers.utils.parseEther('0.0001'), ethers.utils.parseEther('10'))

      const balanceAfter = await ESE.balanceOf(acc2.address)
      const _balanceAfter = await MockERC20.balanceOf(acc2.address)
      const __balanceAfter = await MockERC20.balanceOf(acc4.address)
      //TOO: acc4
      assert.equal(balanceBefore.add(ethers.utils.parseUnits('10', 'ether')).toString(), balanceAfter.toString(), 'Token balance after purchase is correct')
      assert.equal(_balanceAfter.add(ethers.utils.parseUnits('0.0001', 'ether')).toString(), _balanceBefore.toString(), 'Token balance after purchase is correct')
      assert.equal(__balanceBefore.add(ethers.utils.parseUnits('0.0001', 'ether')).toString(), __balanceAfter.toString(), 'Token balance after purchase is correct')
    })
    it('Tokens locked correctly after purchase', async () => {
      const lockedTokensAmount = await ESE.lockedAmount(acc2.address)
      assert.equal(lockedTokensAmount.toString(), ethers.utils.parseEther('5').toString(), 'lockedTokensAmount is correct')
      
    })

    it('Can extend time', async () => {
      await expect(presaleCrowdsale.connect(acc2).extendTime(timeNow + 3*86400))
      .to.be.revertedWith('Ownable: caller is not the owner')
      await expect(presaleCrowdsale.extendTime(timeNow + 3*86400))
      .to.emit(presaleCrowdsale, 'TimedCrowdsaleExtended')
      .withArgs(timeNow + 2*86400, timeNow + 3*86400)
    })

    it('Can\'t buy tokens after closing time', async () => {
      await time.increase(2*86401)
      await expect(presaleCrowdsale.connect(acc2).buyESE(acc2.address, ethers.utils.parseEther('10'), getProof(merkleTree, acc2.address)))
      .to.be.revertedWithCustomError(presaleCrowdsale, 'NotOpen')
    })

    it('Can change wallet', async () => {
      await expect(presaleCrowdsale.connect(acc2).changeWallet(acc2.address))
      .to.be.revertedWith('Ownable: caller is not the owner')
      await expect(presaleCrowdsale.changeWallet(acc2.address))
      .to.emit(presaleCrowdsale, 'ChangeWallet')
      .withArgs(acc4.address, acc2.address)

      assert.equal(await presaleCrowdsale.wallet(), acc2.address, 'wallet is correct')
    })
  })
  