const {
  time, mine
} = require('@nomicfoundation/hardhat-network-helpers')
const { expect } = require('chai')
const { ethers, network } = require('hardhat')
const assert = require('assert')
describe('ESE', function () {
  let ESE
  let signer, acc2, acc3, acc4, acc5, acc6, acc7, acc8, acc9, acc10
  let snapshotId, snapshotId2, snapshotId3
  let TGE
  this.beforeAll(async () => {
    [signer, acc2, acc3, acc4, acc5, acc6, acc7, acc8, acc9, acc10] = await ethers.getSigners()
    const _ESE = await hre.ethers.getContractFactory('ESE')

    ESE = await _ESE.deploy(
      {
          cliff: 15768000,
          duration: 15768000,
          TGEMintShare: 5000,//50%
          beneficiaries: [
            {addr: signer.address, amount:500000000}, 
            {addr: acc2.address, amount:500000000}
          ]
      },
      {
          cliff: 31536000,
          duration: 15768000,
          TGEMintShare: 2000,//20%
          beneficiaries: [
            {addr: signer.address, amount: 1000000000},
            {addr: acc2.address, amount: 1000000000},
            {addr: acc3.address, amount: 1000000000},
            {addr: acc4.address, amount: 1000000000},
            {addr: acc5.address, amount: 1000000000},
            {addr: acc6.address, amount: 1000000000},
            {addr: acc7.address, amount: 1000000000},
            {addr: acc8.address, amount: 1000000000},
            {addr: acc9.address, amount: 1000000000},
            {addr: acc10.address, amount: 1000000000}
          ]
      },
      {
          cliff: 31536000,
          duration: 31536000,
          TGEMintShare: 2000,//20%,
          beneficiaries: [
            {addr:signer.address,amount: 10000000000},
            {addr: acc2.address, amount: 10000000000},
            {addr: acc3.address, amount: 10000000000},
            {addr: acc4.address, amount: 10000000000},
            {addr: acc5.address, amount: 10000000000},
            {addr: acc6.address, amount: 10000000000},
            {addr: acc7.address, amount: 10000000000},
            {addr: acc8.address, amount: 10000000000},
            {addr: acc9.address, amount: 10000000000},
            {addr: acc10.address, amount: 10000000000}
          ]
      },
      {
          cliff: 0,
          duration: 0,
          TGEMintShare: 0,
          beneficiaries: []
      },
      {
          cliff: 0,
          duration: 0,
          TGEMintShare: 0,
          beneficiaries: []
      },
      {
          cliff: 0,
          duration: 0,
          TGEMintShare: 0,
          beneficiaries: []
      }
    )
    await ESE.deployed()
    TGE = (await ethers.provider.getBlock()).timestamp
    //await ESE.transfer(acc2.address, ethers.utils.parseUnits('30000', 'ether'))
    //balanceOfAcc2BeforeAllTransfers = await ESE.balanceOf(acc2.address)
    //balanceOfAcc3BeforeAllTransfers = await ESE.balanceOf(acc3.address)
  })
  it('Init is correct', async () => {
    const presale = await ESE.presale()
    assert.equal(presale.amount, 500000000, 'amount is correct')
    assert.equal(presale.cliff, 15768000, 'cliff is correct')
    assert.equal(presale.duration, 15768000, 'duration is correct')

    const privateSale = await ESE.privateSale()
    assert.equal(privateSale.amount, 8000000000, 'amount is correct')
    assert.equal(privateSale.cliff, 31536000, 'cliff is correct')
    assert.equal(privateSale.duration, 15768000, 'duration is correct')

    const publicSale = await ESE.publicSale()
    assert.equal(publicSale.amount, 80000000000, 'amount is correct')
    assert.equal(publicSale.cliff, 31536000, 'cliff is correct')
    assert.equal(publicSale.duration, 31536000, 'duration is correct')

    assert.equal(await ESE.name(), 'eesee', 'TGE is correct')
    assert.equal(await ESE.symbol(), '$ESE', 'TGE is correct')
    assert.equal((await ESE.decimals()).toString(), '18', 'TGE is correct')
  })

  it('Before cliffs', async () => {
    assert.equal((await ESE.balanceOf(signer.address)).toString(), '2450000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc2.address)).toString(), '2450000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc3.address)).toString(), '2200000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc4.address)).toString(), '2200000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc5.address)).toString(), '2200000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc6.address)).toString(), '2200000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc7.address)).toString(), '2200000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc8.address)).toString(), '2200000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc9.address)).toString(), '2200000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc10.address)).toString(), '2200000000', 'balanceOf is correct')
    
    assert.equal((await ESE.totalSupply()).toString(), '22500000000', 'totalSupply is correct')

    await time.increase(7884000)//3 month later

    assert.equal((await ESE.balanceOf(signer.address)).toString(), '2450000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc2.address)).toString(), '2450000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc3.address)).toString(), '2200000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc4.address)).toString(), '2200000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc5.address)).toString(), '2200000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc6.address)).toString(), '2200000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc7.address)).toString(), '2200000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc8.address)).toString(), '2200000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc9.address)).toString(), '2200000000', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc10.address)).toString(), '2200000000', 'balanceOf is correct')
    
    assert.equal((await ESE.totalSupply()).toString(), '22500000000', 'totalSupply is correct')

    await expect(ESE.connect(signer).transfer(acc10.address, '2450000000'))
      .to.emit(ESE, 'Transfer')
      .withArgs(signer.address, acc10.address, '2450000000')

    assert.equal((await ESE.balanceOf(signer.address)).toString(), '0', 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc10.address)).toString(), '4650000000', 'balanceOf is correct')
  })
  let vestedAmountTransfered
  it('After cliff has started', async () => {
      await time.increase(7884000)//3 month later
      await time.increase(7884000)//3 month later
      const _time = (await ethers.provider.getBlock()).timestamp

      let vestedAmount = 250000000 * (_time - (TGE + 15768000)) / 15768000;
      const vestedAmounts = await ESE.vestedAmounts(signer.address)
      assert.equal(vestedAmounts._presale, parseInt(vestedAmount), 'vestedAmounts is correct')
      assert.equal(vestedAmounts._privateSale, 0, 'vestedAmounts is correct')
      assert.equal(vestedAmounts._publicSale, 0, 'vestedAmounts is correct')

      const totalVestedAmounts = await ESE.totalVestedAmounts()
      assert.equal(totalVestedAmounts._presale, (parseInt(vestedAmount*2)).toString(), 'totalVestedAmounts is correct')
      assert.equal(totalVestedAmounts._privateSale, 0, 'totalVestedAmounts is correct')
      assert.equal(totalVestedAmounts._publicSale, 0, 'totalVestedAmounts is correct')

      assert.equal((await ESE.balanceOf(signer.address)).toString(), (0 + parseInt(vestedAmount)).toString(), 'balanceOf is correct')
      assert.equal((await ESE.balanceOf(acc2.address)).toString(), (2450000000 + parseInt(vestedAmount)).toString(), 'balanceOf is correct')
      
      assert.equal((await ESE.balanceOf(acc3.address)).toString(), '2200000000', 'balanceOf is correct')
      assert.equal((await ESE.balanceOf(acc4.address)).toString(), '2200000000', 'balanceOf is correct')
      assert.equal((await ESE.balanceOf(acc5.address)).toString(), '2200000000', 'balanceOf is correct')
      assert.equal((await ESE.balanceOf(acc6.address)).toString(), '2200000000', 'balanceOf is correct')
      assert.equal((await ESE.balanceOf(acc7.address)).toString(), '2200000000', 'balanceOf is correct')
      assert.equal((await ESE.balanceOf(acc8.address)).toString(), '2200000000', 'balanceOf is correct')
      assert.equal((await ESE.balanceOf(acc9.address)).toString(), '2200000000', 'balanceOf is correct')
      assert.equal((await ESE.balanceOf(acc10.address)).toString(), '4650000000', 'balanceOf is correct')
      await mine()
      const __time = (await ethers.provider.getBlock()).timestamp + 1
      vestedAmount += 250000000 * (__time - _time) / 15768000;
      await time.setNextBlockTimestamp(__time)

      await expect(ESE.connect(acc2).transfer(acc10.address, (2450000001 + parseInt(vestedAmount)).toString()))
      .to.be.revertedWith("ERC20: transfer amount exceeds balance")

      
      await mine()
      const ___time = (await ethers.provider.getBlock()).timestamp + 1
      vestedAmount += 250000000 * (___time - __time) / 15768000;
      await time.setNextBlockTimestamp(___time)
      vestedAmountTransfered = parseInt(vestedAmount)

      await expect(await ESE.connect(acc2).transfer(acc10.address, (2450000000 + parseInt(vestedAmount)).toString()))
      .to.emit(ESE, 'Transfer')
      .withArgs(acc2.address, acc10.address, (2450000000 + parseInt(vestedAmount)).toString())
      .to.emit(ESE, 'Transfer')
      .withArgs("0x0000000000000000000000000000000000000000", acc2.address, parseInt(vestedAmount).toString())

      assert.equal((await ESE.balanceOf(acc10.address)).toString(), (7100000000 + parseInt(vestedAmount)).toString(), 'balanceOf is correct')
      assert.equal((await ESE.balanceOf(acc2.address)).toString(), '0', 'balanceOf is correct')
  })

  it('Cliff has ended', async () => {
    await time.increase(7884000)//3 month later
    await time.increase(7884000)//3 month later
    await mine()
    const _time = (await ethers.provider.getBlock()).timestamp

    let vestedAmount = 800000000 * (_time - (TGE + 31536000)) / 15768000;
    let vestedAmount2 = 8000000000 * (_time - (TGE + 31536000)) / 31536000;

    const vestedAmounts = await ESE.vestedAmounts(acc3.address)
    assert.equal(vestedAmounts._presale, 0, 'vestedAmounts is correct')
    assert.equal(vestedAmounts._privateSale, parseInt(vestedAmount), 'vestedAmounts is correct')
    assert.equal(vestedAmounts._publicSale, parseInt(vestedAmount2), 'vestedAmounts is correct')

    const totalVestedAmounts = await ESE.totalVestedAmounts()
    assert.equal(totalVestedAmounts._presale, 500000000, 'totalVestedAmounts is correct')
    assert.equal(totalVestedAmounts._privateSale, parseInt(vestedAmount*10), 'totalVestedAmounts is correct')
    assert.equal(totalVestedAmounts._publicSale, parseInt(vestedAmount2*10), 'totalVestedAmounts is correct')

    assert.equal((await ESE.balanceOf(signer.address)).toString(), (250000000 + parseInt(vestedAmount) + parseInt(vestedAmount2)).toString(), 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc2.address)).toString(), (250000000 - vestedAmountTransfered + parseInt(vestedAmount) + parseInt(vestedAmount2)).toString(), 'balanceOf is correct')
  
    assert.equal((await ESE.balanceOf(acc3.address)).toString(), (2200000000 + parseInt(vestedAmount) + parseInt(vestedAmount2)).toString(), 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc4.address)).toString(), (2200000000 + parseInt(vestedAmount) + parseInt(vestedAmount2)).toString(), 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc5.address)).toString(), (2200000000 + parseInt(vestedAmount) + parseInt(vestedAmount2)).toString(), 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc6.address)).toString(), (2200000000 + parseInt(vestedAmount) + parseInt(vestedAmount2)).toString(), 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc7.address)).toString(), (2200000000 + parseInt(vestedAmount) + parseInt(vestedAmount2)).toString(), 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc8.address)).toString(), (2200000000 + parseInt(vestedAmount) + parseInt(vestedAmount2)).toString(), 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc9.address)).toString(), (2200000000 + parseInt(vestedAmount) + parseInt(vestedAmount2)).toString(), 'balanceOf is correct')
    assert.equal((await ESE.balanceOf(acc10.address)).toString(), (7100000000 + vestedAmountTransfered + parseInt(vestedAmount) + parseInt(vestedAmount2)).toString(), 'balanceOf is correct')
    await mine()
    const __time = (await ethers.provider.getBlock()).timestamp + 1
    vestedAmount += 800000000 * (__time - _time) / 15768000;
    vestedAmount2 += 8000000000 * (__time - _time) / 31536000;
    await time.setNextBlockTimestamp(__time)

    await expect(await ESE.connect(acc3).transfer(acc10.address, (2200000000 + parseInt(vestedAmount) + parseInt(vestedAmount2)).toString()))
      .to.emit(ESE, 'Transfer')
      .withArgs(acc3.address, acc10.address, (2200000000 + parseInt(vestedAmount) + parseInt(vestedAmount2)).toString())
      .to.emit(ESE, 'Transfer')
      .withArgs("0x0000000000000000000000000000000000000000", acc3.address, (parseInt(vestedAmount) + parseInt(vestedAmount2)).toString())
  
      assert.equal((await ESE.balanceOf(acc3.address)).toString(), '0', 'balanceOf is correct')
      assert.equal((await ESE.balanceOf(acc10.address)).toString(), (9300000000 + vestedAmountTransfered + 2*parseInt(vestedAmount) + 2*parseInt(vestedAmount2)).toString(), 'balanceOf is correct')
  })
  it('all cliffs have ended', async () => {

  })
  it('deploy with a lot of addresses', async () => {
    const _ESE = await hre.ethers.getContractFactory('ESE')

    function getRandomInt(max) {
      return Math.floor(Math.random() * max);
    }

    let presaleBeneficiaries = []
    let privateSaleBeneficiaries = []
    let publicSaleBeneficiaries = []
    for (let i = 0; i < 280; i++) {
      let wallet = ethers.Wallet.createRandom()
      presaleBeneficiaries.push({addr:wallet.address, amount: getRandomInt(200) })
      privateSaleBeneficiaries.push({addr:wallet.address, amount: getRandomInt(200) })
      publicSaleBeneficiaries.push({addr:wallet.address, amount: getRandomInt(200) })
    }

    ESE = await _ESE.deploy(
      {
          cliff: 15768000,
          duration: 15768000,
          TGEMintShare: 5000,//50%
          beneficiaries: presaleBeneficiaries
      },
      {
          cliff: 31536000,
          duration: 15768000,
          TGEMintShare: 2000,//20%
          beneficiaries: privateSaleBeneficiaries
      },
      {
          cliff: 31536000,
          duration: 31536000,
          TGEMintShare: 2000,//20%,
          beneficiaries: publicSaleBeneficiaries
      },
      {
          cliff: 0,
          duration: 0,
          TGEMintShare: 0,
          beneficiaries: []
      },
      {
          cliff: 0,
          duration: 0,
          TGEMintShare: 0,
          beneficiaries: []
      },
      {
          cliff: 0,
          duration: 0,
          TGEMintShare: 0,
          beneficiaries: []
      }
    )
    tx = await ESE.deployed()
    console.log('gasLimit:', tx.deployTransaction.gasLimit.toString())
  })

  it('cannot mint more than maxint in constructor', async () => {
    const _ESE = await hre.ethers.getContractFactory('ESE')
    await expect(_ESE.deploy(
      {
          cliff: 15768000,
          duration: 15768000,
          TGEMintShare: 1,//0.01%
          beneficiaries: [{addr: signer.address, amount: '115792089237316195423570985008687907853269984665640564039457584007913129639935'}]
      },
      {
          cliff: 0,
          duration: 0,
          TGEMintShare: 0,
          beneficiaries: []
      },
      {
          cliff: 0,
          duration: 0,
          TGEMintShare: 0,
          beneficiaries: []
      },
      {
          cliff: 0,
          duration: 0,
          TGEMintShare: 0,
          beneficiaries: []
      },
      {
          cliff: 0,
          duration: 0,
          TGEMintShare: 0,
          beneficiaries: []
      },
      {
          cliff: 0,
          duration: 0,
          TGEMintShare: 0,
          beneficiaries: [{addr: signer.address, amount: '1'}]
      }
    ))
    .to.be.revertedWithPanic("0x11")
  })
})