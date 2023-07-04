const { expect } = require('chai');
const { ethers } = require('hardhat');
const assert = require('assert');
describe('eeseeFeeSplitter', function () {
    let erc20, eeseeFeeSplitter
    let signer, miningPool, companyTreasury, daoTreasury, stakingPool, acc1, companyTreasuryNew
    this.beforeAll(async () => {
        [signer, miningPool, companyTreasury, daoTreasury, stakingPool, acc1, companyTreasuryNew] = await ethers.getSigners()
        const mockERC20ContractFactory = await hre.ethers.getContractFactory('MockERC20')
        const eeseeFeeSplitterContractFactory = await hre.ethers.getContractFactory('eeseeFeeSplitter')
        erc20 = await mockERC20ContractFactory.deploy('10000000000000')
        await erc20.deployed()
        eeseeFeeSplitter = await eeseeFeeSplitterContractFactory.deploy(
            erc20.address,
            {
                addr: companyTreasury.address,
                share: ethers.utils.parseEther('0.5')
            },
            {
                addr: miningPool.address,
                share: ethers.utils.parseEther('0.3')
            },
            {
                addr: daoTreasury.address,
                share: ethers.utils.parseEther('0.1')
            },
            {
                addr: stakingPool.address,
                share: ethers.utils.parseEther('0.1')
            }
        )
        await eeseeFeeSplitter.deployed()
    })
    it('Can split payment', async () => {
        await expect(eeseeFeeSplitter.connect(signer).splitFees()).to.be.revertedWithCustomError(eeseeFeeSplitter, 'ZeroBalance')
        await erc20.transfer(eeseeFeeSplitter.address, '100000000')
        const companyTreasuryBalanceBefore = await erc20.balanceOf(companyTreasury.address)
        const miningPoolBalanceBefore = await erc20.balanceOf(miningPool.address)
        const daoTreasuryBalanceBefore = await erc20.balanceOf(daoTreasury.address)
        const stakingPoolBalanceBefore = await erc20.balanceOf(stakingPool.address)
        await expect(eeseeFeeSplitter.connect(signer).splitFees())
        .to.emit(erc20, 'Transfer')
        .withArgs(eeseeFeeSplitter.address, companyTreasury.address, '50000000')
        .and.to.emit(erc20, 'Transfer')
        .withArgs(eeseeFeeSplitter.address, miningPool.address, '30000000')
        .and.to.emit(erc20, 'Transfer')
        .withArgs(eeseeFeeSplitter.address, daoTreasury.address, '10000000')
        .and.to.emit(erc20, 'Transfer')
        .withArgs(eeseeFeeSplitter.address, stakingPool.address, '10000000')
        .to.emit(eeseeFeeSplitter, 'SplitFees')
        .withArgs(companyTreasury.address, '50000000','30000000',  '10000000', '10000000')
        const companyTreasuryBalanceAfter = await erc20.balanceOf(companyTreasury.address)
        const miningPoolBalanceAfter = await erc20.balanceOf(miningPool.address)
        const daoTreasuryBalanceAfter = await erc20.balanceOf(daoTreasury.address)
        const stakingPoolBalanceAfter = await erc20.balanceOf(stakingPool.address)
        assert.equal(companyTreasuryBalanceAfter.toString(), companyTreasuryBalanceBefore.add(ethers.BigNumber.from('50000000')).toString(), "companyTreasury balance is correct")
        assert.equal(miningPoolBalanceAfter.toString(), miningPoolBalanceBefore.add(ethers.BigNumber.from('30000000')).toString(), "miningPool balance is correct")
        assert.equal(daoTreasuryBalanceAfter.toString(), daoTreasuryBalanceBefore.add(ethers.BigNumber.from('10000000')).toString(), "daoTreasury balance is correct")
        assert.equal(stakingPoolBalanceAfter.toString(), stakingPoolBalanceBefore.add(ethers.BigNumber.from('10000000')).toString(), "stakingPool balance is correct")
    })
    it('Can set shares', async () => {
        await expect(eeseeFeeSplitter.connect(signer).setShares(ethers.utils.parseEther('0.2'), ethers.utils.parseEther('0.2'), ethers.utils.parseEther('0.2'), ethers.utils.parseEther('0.2')))
            .to.be.revertedWithCustomError(eeseeFeeSplitter, 'InvalidShares')
        await expect(eeseeFeeSplitter.connect(signer).setShares(ethers.utils.parseEther('0.6'), ethers.utils.parseEther('0.2'), ethers.utils.parseEther('0.1'), ethers.utils.parseEther('0.1')))
            .to.be.revertedWithCustomError(eeseeFeeSplitter, 'InvalidCompanyTreasuryShare')
        await expect(eeseeFeeSplitter.connect(acc1).setShares(ethers.utils.parseEther('0.1'), ethers.utils.parseEther('0.5'), ethers.utils.parseEther('0.3'), ethers.utils.parseEther('0.1')))
            .to.be.revertedWith("Ownable: caller is not the owner")
        await expect(eeseeFeeSplitter.connect(signer).setShares(ethers.utils.parseEther('0.3'), ethers.utils.parseEther('0.2'), ethers.utils.parseEther('0.2'), ethers.utils.parseEther('0.3')))
        .to.emit(eeseeFeeSplitter, 'SetShares')
        .withArgs(
                ethers.utils.parseEther('0.3'),
                ethers.utils.parseEther('0.2'),
                ethers.utils.parseEther('0.2'),
                ethers.utils.parseEther('0.3')
        )
        await erc20.transfer(eeseeFeeSplitter.address, '100000000')
        await expect(eeseeFeeSplitter.connect(signer).splitFees())
        .to.emit(erc20, 'Transfer')
        .withArgs(eeseeFeeSplitter.address, companyTreasury.address, '30000000')
        .and.to.emit(erc20, 'Transfer')
        .withArgs(eeseeFeeSplitter.address, miningPool.address, '20000000')
        .and.to.emit(erc20, 'Transfer')
        .withArgs(eeseeFeeSplitter.address, daoTreasury.address, '20000000')
        .and.to.emit(erc20, 'Transfer')
        .withArgs(eeseeFeeSplitter.address, stakingPool.address, '30000000')
        .to.emit(eeseeFeeSplitter, 'SplitFees')
        .withArgs(companyTreasury.address, '30000000', '20000000', '20000000', '30000000')
    })
    it('Can set company treasury address', async () => {
        await expect(eeseeFeeSplitter.connect(signer).setCompanyTreasuryAddress('0x0000000000000000000000000000000000000000')).to.be.revertedWithCustomError(eeseeFeeSplitter, 'InvalidAddress')
        await expect(eeseeFeeSplitter.connect(acc1).setCompanyTreasuryAddress(companyTreasuryNew.address)).to.be.revertedWith("Ownable: caller is not the owner")
        await expect(eeseeFeeSplitter.connect(signer).setCompanyTreasuryAddress(companyTreasuryNew.address))
        .to.emit(eeseeFeeSplitter, 'SetCompanyTreasuryAddress')
        .withArgs(companyTreasury.address, companyTreasuryNew.address)
        await erc20.transfer(eeseeFeeSplitter.address, '100000000')
        await expect(eeseeFeeSplitter.connect(signer).splitFees())
        .to.emit(erc20, 'Transfer')
        .withArgs(eeseeFeeSplitter.address, companyTreasuryNew.address, '30000000')
        .and.to.emit(erc20, 'Transfer')
        .withArgs(eeseeFeeSplitter.address, miningPool.address, '20000000')
        .and.to.emit(erc20, 'Transfer')
        .withArgs(eeseeFeeSplitter.address, daoTreasury.address, '20000000')
        .and.to.emit(erc20, 'Transfer')
        .withArgs(eeseeFeeSplitter.address, stakingPool.address, '30000000')
        .to.emit(eeseeFeeSplitter, 'SplitFees')
        .withArgs(companyTreasuryNew.address, '30000000', '20000000', '20000000', '30000000')
    })
})