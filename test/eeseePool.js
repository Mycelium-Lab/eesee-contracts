const { expect } = require('chai');
const { ethers } = require('hardhat');
const assert = require('assert');
const { StandardMerkleTree } = require('@openzeppelin/merkle-tree');
describe('eeseePool', function () {
    let claimerWallet = null;
    let claimerWalletBalances = []
    let ESE;
    let pool;
    let leavesOfMerkleTrees = [];
    let merkleTrees = [];
    const getRandomInt = (min, max) => {
        min = Math.ceil(min);
        max = Math.floor(max);
        return Math.floor(Math.random() * (max - min + 1)) + min;
    }
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
    const oneAddress = "0x0000000000000000000000000000000000000001"
    this.beforeAll(async() => {
        [signer, acc2, claimerWallet] = await ethers.getSigners()
        
        const _ESE = await hre.ethers.getContractFactory('ESE');
        const _pool = await hre.ethers.getContractFactory('eeseePool');
        const _privateSale = await hre.ethers.getContractFactory('ESECrowdsale')

        const mockPresale = await _privateSale.deploy(125000000000000, oneAddress, oneAddress, oneAddress, 1000000000, 200000000000, 9999999999, 99999999991, '0x0000000000000000000000000000000000000000000000000000000000000000')
        await mockPresale.deployed()

        const mockPrivateSale = await _privateSale.deploy(71428571428571, oneAddress, oneAddress, oneAddress, 14000000000, 1660000000000, 9999999999, 99999999991, '0x0000000000000000000000000000000000000000000000000000000000000000')
        await mockPrivateSale.deployed()

        ESE = await _ESE.deploy(
            '1000000000000000000000000', 
            '50000000000000000000000000', 
            mockPresale.address, 
            31536000, 
            '90000000000000000000000000', 
            mockPrivateSale.address, 
            10, 
            5184000
        )
        await ESE.deployed()
        
        pool = await _pool.deploy(ESE.address)
        await pool.deployed()

        for (let i = 0; i < 5; i ++) {
            let leaves = [];
            for (let j = 0; j < 10; j ++) {
                const wallet = ethers.Wallet.createRandom().connect(ethers.provider)
                const randomInt = getRandomInt(1, 1000000).toString()
                leaves.push([
                    wallet.address, randomInt
                ])
            }
            //if (i !== 0) {
                let randomInt = getRandomInt(1, 1000000).toString()
                leaves.push([
                    claimerWallet.address, randomInt
                ])
                claimerWalletBalances.push(randomInt)
            //}
            leavesOfMerkleTrees.push(leaves)
            merkleTrees.push(StandardMerkleTree.of(leaves, ['address', 'uint256']))
        }

        await signer.sendTransaction({to:claimerWallet.address, value: ethers.utils.parseEther('1.0')})
        await ESE.transfer(pool.address, '1000000000000000000000')
    })
    it('Check initial values', async () => {
        const owner = await pool.owner()
        const rewardToken = await pool.rewardToken()
        const rewardId = await pool.rewardID()
        const rewardRoot = await pool.rewardRoot(rewardId)
        assert.equal(owner, signer.address, 'Owner is correct')
        assert.equal(rewardId.toString(), '0', 'Reward ID is correct')
        assert.equal(rewardToken, ESE.address, 'Reward token is correct')
        assert.equal(rewardRoot, '0x0000000000000000000000000000000000000000000000000000000000000000', 'Reward root is correct')
    })
    it('Can add rewards', async () => {
        await expect(pool.connect(acc2).addReward(merkleTrees[0].root)).to.be.revertedWith('Ownable: caller is not the owner')
        for(const merkleTree of merkleTrees) {
            const rewardId = await pool.rewardID()
            await expect(pool.connect(signer).addReward(merkleTree.root)).to.emit(pool, 'RewardAdded').withArgs(rewardId, merkleTree.root)
            const rewardIdAfterNewReward = await pool.rewardID()
            assert.equal(rewardIdAfterNewReward.toString(), (parseInt(rewardId) + 1).toString(), 'Reward ID is correct')
            const rewardRoot = await pool.rewardRoot(rewardId)
            assert.equal(merkleTree.root, rewardRoot, 'rewardRoot is correct')
        }
    })
    it('verifyClaim function is correct', async () => {
        const claims = leavesOfMerkleTrees[0].map((leaf) => {
            return {
                rewardID: '0',
                balance: leaf[1],
                merkleProof: getProof(merkleTrees[0], leaf[0])
            }
        })
        for (let i = 0; i < leavesOfMerkleTrees[0].length; i++) {
            const verifyClaim = await pool.verifyClaim(leavesOfMerkleTrees[0][i][0], claims[i])
            assert.equal(verifyClaim, true, `verifyClaim for ${leavesOfMerkleTrees[0][i][0]} is correct.`)
            const verifyClaimFalse = await pool.verifyClaim(ethers.Wallet.createRandom().address, claims[i])
            assert.equal(verifyClaimFalse, false, `verifyClaim is correct.`)
        }
    })
    it('getRewards function is correct', async () => {
        const claims = claimerWalletBalances.map((balance, index) => {
            return {
                rewardID: index.toString(),
                balance: balance.toString(),
                merkleProof: getProof(merkleTrees[index], claimerWallet.address)
            }
        })
        const rewards = await pool.getRewards(claimerWallet.address, claims)
        const expectedBalanceAfter = claimerWalletBalances.reduce((acc, current) => {
            return acc.add(current)
        }, ethers.BigNumber.from('0'))
        assert.equal(rewards.toString(), expectedBalanceAfter.toString(), 'getRewards is correct')
    })
    it('Can claim multiple rewards', async () => {
        const claims = claimerWalletBalances.map((balance, index) => {
            return {
                rewardID: index.toString(),
                balance: balance.toString(),
                merkleProof: getProof(merkleTrees[index], claimerWallet.address)
            }
        })
        const balanceBefore = await ESE.balanceOf(pool.address)
        await expect(pool.connect(acc2).claimRewards(claims)).to.be.revertedWith('eesee: Invalid merkle proof')
        await expect(pool.connect(claimerWallet).claimRewards([claims[0], claims[4]])).to.emit(pool, 'RewardClaimed')
        .withArgs('0', claimerWallet.address, claimerWalletBalances[0].toString())
        .and.to.emit(pool, "RewardClaimed")
        .withArgs('4', claimerWallet.address, claimerWalletBalances[4].toString())
        await expect(pool.connect(claimerWallet).claimRewards([claims[0], claims[1]])).to.be.revertedWith('eesee: Already claimed')
        await expect(pool.connect(claimerWallet).claimRewards([claims[1], claims[2], claims[3]])).to.emit(pool, 'RewardClaimed')
        .withArgs('1', claimerWallet.address, claimerWalletBalances[1].toString())
        .and.to.emit(pool, "RewardClaimed")
        .withArgs('2', claimerWallet.address, claimerWalletBalances[2].toString())
        .and.to.emit(pool, "RewardClaimed")
        .withArgs('3', claimerWallet.address, claimerWalletBalances[3].toString())
        
        const balanceAfter = await ESE.balanceOf(pool.address)
        const expectedBalanceAfter = claimerWalletBalances.reduce((acc, current) => {
            return acc.add(current)
        }, ethers.BigNumber.from('0'))
        assert.equal(balanceBefore.sub(expectedBalanceAfter).toString(), balanceAfter.toString(), 'Balance after claim is correct')
        await expect(pool.connect(claimerWallet).claimRewards(claims)).to.be.revertedWith('eesee: Already claimed')
    })
})