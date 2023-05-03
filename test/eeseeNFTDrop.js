const {
    time,
    loadFixture,
  } = require("@nomicfoundation/hardhat-network-helpers");
  const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
  const { expect } = require("chai");
  const { ethers, network } = require("hardhat");
  const { StandardMerkleTree } = require('@openzeppelin/merkle-tree');
  const assert = require("assert");
  describe("eesee", function () {
    const publicStage = {
        name: 'Public Stage',
        mintFee: 0,
        duration: 86400,
        perAddressMintLimit: 0,
        allowListMerkleRoot: '0x0000000000000000000000000000000000000000000000000000000000000000'
    }
    const presaleStages = [
        {
            name: 'Presale Stage 1',
            mintFee: 0,
            duration: 86400,
            perAddressMintLimit: 0,
            allowListMerkleRoot: '' // adds merkle root in befor all hook
        },
        {
            name: 'Presale Stage 2',
            mintFee: 0,
            duration: 86400,
            perAddressMintLimit: 5,
            allowListMerkleRoot: '0x0000000000000000000000000000000000000000000000000000000000000000'
        },
        {
            name: 'Presale Stage 3',
            mintFee: ethers.utils.parseUnits('0.001', 'ether'),
            duration: 86400,
            perAddressMintLimit: 0,
            allowListMerkleRoot: '0x0000000000000000000000000000000000000000000000000000000000000000'
        },
        {
            name: 'Presale Stage 4',
            mintFee: ethers.utils.parseUnits('0.002', 'ether'),
            duration: 86400,
            perAddressMintLimit: 0,
            allowListMerkleRoot: '0x0000000000000000000000000000000000000000000000000000000000000000'
        },
        {
            name: 'Presale Stage 5',
            mintFee: ethers.utils.parseUnits('0.003', 'ether'),
            duration: 86400,
            perAddressMintLimit: 0,
            allowListMerkleRoot: '0x0000000000000000000000000000000000000000000000000000000000000000'
        }
    ]
    const presalesDuration0 = [
        {
            name: 'Presale Duration 0',
            mintFee: ethers.utils.parseUnits('0.005', 'ether'),
            duration: 0,
            perAddressMintLimit: 0,
            allowListMerkleRoot: '0x0000000000000000000000000000000000000000000000000000000000000000'
        }
    ]
    const getProof = (tree, address) => {
        let proof = null
        for (const [i, v] of tree.entries()) {
            if (v[0] === address) {
                proof = tree.getProof(i);
              }
        }
        return proof
    }
    let ESE;
    let pool;
    let mockVRF;
    let eesee;
    let eeseeNFTDrop;
    let signer, acc2, acc3, acc4, acc5, acc6, acc7, acc8, feeCollector;
    let ticketBuyers;
    let minter;
    let royaltyEninge;
    let currentTimestamp;
    let merkleTreeOfPresale1;
    let leaves = []
    //after one year
    const timeNow = Math.round((new Date()).getTime() / 1000);
    const zeroAddress = "0x0000000000000000000000000000000000000000"
  
    this.beforeAll(async() => {
        [signer, acc2, acc3, acc4, acc5, acc6, acc7, earningsCollector, feeCollector, royaltyCollector] = await ethers.getSigners()
        ticketBuyers = [acc2,acc3, acc4, acc5, acc6,  acc7]
        const _ESE = await hre.ethers.getContractFactory("ESE");
        const _pool = await hre.ethers.getContractFactory("eeseePool");
        const _mockVRF = await hre.ethers.getContractFactory("MockVRFCoordinator");
        const _eesee = await hre.ethers.getContractFactory("eesee");
        const _minter = await hre.ethers.getContractFactory("eeseeMinter");
        const _royaltyEngine = await hre.ethers.getContractFactory("MockRoyaltyEngine");
        const _eeseeNFTDrop = await hre.ethers.getContractFactory("eeseeNFTDrop")
        ESE = await _ESE.deploy('1000000000000000000000000')
        await ESE.deployed()
        
        pool = await _pool.deploy(ESE.address)
        await pool.deployed()

        mockVRF = await _mockVRF.deploy()
        await mockVRF.deployed()

        minter = await _minter.deploy('baseURI.com/', 'contractURI.com/')
        await minter.deployed()

        royaltyEninge = await _royaltyEngine.deploy();
        await royaltyEninge.deployed()

        eesee = await _eesee.deploy(
            ESE.address, 
            pool.address, 
            minter.address, 
            feeCollector.address, 
            royaltyEninge.address, 
            mockVRF.address,
            zeroAddress,//ChainLink token
            '0x0000000000000000000000000000000000000000000000000000000000000000',//Key Hash
            0,//minimumRequestConfirmations
            50000//callbackGasLimit
        )
        await eesee.deployed()
        currentTimestamp = (await ethers.provider.getBlock()).timestamp;
        for (let j = 0; j < 9; j ++) {
            const wallet = ethers.Wallet.createRandom().connect(ethers.provider)
            leaves.push([
                wallet.address
            ])
        }
        leaves.push([acc2.address])
        merkleTreeOfPresale1 = StandardMerkleTree.of(leaves, ['address'])
        presaleStages[0].allowListMerkleRoot = merkleTreeOfPresale1.root
        eeseeNFTDrop = await _eeseeNFTDrop.deploy(
            'ABCDFG',
            'ABC',
            '/',
            '/',
            { receiver: royaltyCollector.address, royaltyFraction: 300 },
            35, 
            earningsCollector.address,
            eesee.address,
            currentTimestamp + 86400,
            publicStage,
            presaleStages
        )
        await eeseeNFTDrop.deployed()
    })
    it('Owner can set mint options', async () => {
        currentTimestamp = (await ethers.provider.getBlock()).timestamp;
        await expect(eeseeNFTDrop.connect(acc2).setMintStageOptions(currentTimestamp + 86400, publicStage, presaleStages)).to.be.revertedWith('Ownable: caller is not the owner')
        await expect(eeseeNFTDrop.connect(signer).setMintStageOptions(currentTimestamp - 86400, publicStage, presaleStages)).to.be.revertedWith('eeseeNFTDrop: Mint start timestamp must be in the future.')
        await expect(eeseeNFTDrop.connect(signer).setMintStageOptions(currentTimestamp + 86400, publicStage, presalesDuration0)).to.be.revertedWith('eeseeNFTDrop: Duration of a sale stage can\'t be 0.')
        await expect(eeseeNFTDrop.connect(signer).setMintStageOptions(currentTimestamp + 86400, publicStage, [...presaleStages, presaleStages[0]])).to.be.revertedWith('eeseeNFTDrop: Maximum amount of presale stages is 5.')
        await expect(eeseeNFTDrop.connect(signer).setMintStageOptions(currentTimestamp + 86400, publicStage, []))
        .to.emit(eeseeNFTDrop, "MintOptionsChanged")
        .withArgs(currentTimestamp + 86400, Object.keys(publicStage).map((key) => publicStage[key]), [])
        await expect(eeseeNFTDrop.connect(signer).setMintStageOptions(currentTimestamp + 86400, publicStage, presaleStages))
        .to.emit(eeseeNFTDrop, "MintOptionsChanged")
        .withArgs(currentTimestamp + 86400, Object.keys(publicStage).map((key) => publicStage[key]), anyValue)
    })
    it('Options are set correctly', async () => {
        let timePassed = ethers.BigNumber.from(currentTimestamp).add(ethers.BigNumber.from(86400))
        for(let i = 0; i < presaleStages.length; i ++){
            const presaleStageInfo = await eeseeNFTDrop.stages(i)
            Object.keys(presaleStages[i]).forEach((presaleStageKey) => {
                assert.equal(presaleStages[i][presaleStageKey].toString(), presaleStageInfo.stageOptions[presaleStageKey].toString(), `Presale option ${presaleStageKey} is correct.`)
            })
            assert.equal(presaleStageInfo.startTimestamp.toString(), timePassed.toString(), `Presale ${i} start timestamp is correct`)
            timePassed = timePassed.add(presaleStageInfo.stageOptions.duration)
            assert.equal(presaleStageInfo.endTimestamp.toString(), timePassed.toString(), `Presale ${i} end timestamp is correct`)
            timePassed = timePassed.add(ethers.BigNumber.from(1))
        }
        const publicStageInfo = await eeseeNFTDrop.stages(presaleStages.length)
        Object.keys(publicStage).forEach((publicStageKey) => {
            assert.equal(publicStage[publicStageKey].toString(), publicStageInfo.stageOptions[publicStageKey].toString(), `Public stage option ${publicStageKey} is correct.`)
        })
        assert.equal(publicStageInfo.startTimestamp.toString(), timePassed.toString(), 'Public stage start timestamp is correct')
        timePassed = timePassed.add(publicStageInfo.stageOptions.duration)
        assert.equal(publicStageInfo.endTimestamp.toString(), timePassed.toString(), 'Public stage end timestamp is correct')
    })
    it('Can\'t mint if it hasn\'t started yet.', async () => {
        await expect(eeseeNFTDrop.connect(acc2).mint(10, []))
        .to.be.revertedWith('eeseeNFTDrop: Mint hasn\'t started yet.')
    })
    it('Can change mint limit and earnings collector if mint hasn\'t started', async () => {
        await expect(eeseeNFTDrop.connect(acc4).setMintLimit(35))
        .to.be.revertedWith('Ownable: caller is not the owner')
        await expect(eeseeNFTDrop.connect(signer).setMintLimit(100))
        .to.emit(eeseeNFTDrop, "MintLimitChanged")
        .withArgs(100)
        await expect(eeseeNFTDrop.connect(signer).setMintLimit(35))
        .to.emit(eeseeNFTDrop, "MintLimitChanged")
        .withArgs(35)
        await expect(eeseeNFTDrop.connect(acc4).setEarningsCollector(acc2.address))
        .to.be.revertedWith('Ownable: caller is not the owner')
        await expect(eeseeNFTDrop.connect(signer).setEarningsCollector(acc2.address))
        .to.emit(eeseeNFTDrop, "EarningsCollectorChanged")
        .withArgs(acc2.address)
        await expect(eeseeNFTDrop.connect(signer).setEarningsCollector(earningsCollector.address))
        .to.emit(eeseeNFTDrop, "EarningsCollectorChanged")
        .withArgs(earningsCollector.address)
    })
    it('Can\'t change mint settings if it has already started', async () => {
        // Presale 1
        await time.increase(86401)
        await expect(eeseeNFTDrop.connect(signer).setMintStageOptions(currentTimestamp + 300000, publicStage, presaleStages))
        .to.be.revertedWith('eeseeNFTDrop: Can\'t change mint settings if it has already started.')
        await expect(eeseeNFTDrop.connect(signer).setMintLimit(100))
        .to.be.revertedWith('eeseeNFTDrop: Mint has already started.')
        await expect(eeseeNFTDrop.connect(signer).setEarningsCollector(acc2.address))
        .to.be.revertedWith('eeseeNFTDrop: Mint has already started.')
    })
    it('Can mint in presale stage if in allowlist', async () => {
        const invalidMerkleTree = StandardMerkleTree.of([...leaves, [acc3.address]], ['address'])
        await expect(eeseeNFTDrop.connect(acc3).mint(10, getProof(invalidMerkleTree, acc3.address)))
        .to.be.revertedWith('eeseeNFTDrop: You are not in the allowlist of current sale stage.')
        await expect(eeseeNFTDrop.connect(acc2).mint(10, getProof(merkleTreeOfPresale1, acc2.address)))
        .to.emit(eeseeNFTDrop, "Transfer")
        .withArgs('0x0000000000000000000000000000000000000000', acc2.address, 1)
        .to.emit(eeseeNFTDrop, "Transfer")
        .withArgs('0x0000000000000000000000000000000000000000', acc2.address, 10)
    })
    it('Can\'t mint more than per address limit', async () => {
        // Presale 2
        await time.increase(86401)
        await expect(eeseeNFTDrop.connect(acc3).mint(10, []))
        .to.be.revertedWith('eeseeNFTDrop: You reached address mint limit.')
        await expect(eeseeNFTDrop.connect(acc3).mint(5, []))
        .to.emit(eeseeNFTDrop, "Transfer")
        .withArgs('0x0000000000000000000000000000000000000000', acc3.address, 11)
        .to.emit(eeseeNFTDrop, "Transfer")
        .withArgs('0x0000000000000000000000000000000000000000', acc3.address, 15)
        await expect(eeseeNFTDrop.connect(acc3).mint(1, []))
        .to.be.revertedWith('eeseeNFTDrop: You reached address mint limit.')
        await expect(eeseeNFTDrop.connect(acc2).mint(5, []))
        .to.emit(eeseeNFTDrop, "Transfer")
        .withArgs('0x0000000000000000000000000000000000000000', acc2.address, 16)
        .to.emit(eeseeNFTDrop, "Transfer")
        .withArgs('0x0000000000000000000000000000000000000000', acc2.address, 20)
    })
    it('All fees and earnings are sent correctly after mint', async () => {
        const amountOfNFTToMint = 10
        // Presale 3
        await time.increase(86401)
        await expect(eeseeNFTDrop.connect(acc2).mint(10, []))
        .to.be.revertedWith('eeseeNFTDrop: Insufficient funds for this amount.')
        const acc2BalanceBefore = await ethers.provider.getBalance(acc2.address)
        const feeCollectorBalanceBefore = await ethers.provider.getBalance(feeCollector.address)
        const earningsCollectorBalanceBefore = await ethers.provider.getBalance(earningsCollector.address)
        const mintTx = await eeseeNFTDrop.connect(acc2).mint(amountOfNFTToMint, [], {value: ethers.utils.parseEther("0.1")})
        const mintReceipt = await mintTx.wait()
        const mintTxGasCost = mintReceipt.gasUsed.mul(mintReceipt.effectiveGasPrice)
        const mintFeeCost = ethers.utils.parseEther((0.001 * amountOfNFTToMint).toString())
        const acc2BalanceAfter = await ethers.provider.getBalance(acc2.address)
        const acc2ExpectedBalanceAfter = acc2BalanceBefore.sub(mintFeeCost).sub(mintTxGasCost)
        assert.equal(acc2ExpectedBalanceAfter.toString(), acc2BalanceAfter.toString(), 'Balance after mint transaction is correct.')
        const feeCollectorBalanceAfter = await ethers.provider.getBalance(feeCollector.address)
        const feeAmount = mintFeeCost.div(ethers.BigNumber.from(10))
        const feeCollectorExpectedBalanceAfter = feeCollectorBalanceBefore.add(feeAmount)
        assert.equal(feeCollectorExpectedBalanceAfter.toString(), feeCollectorBalanceAfter.toString(), 'Fee collector balance is correct.')
        const earningsCollectorBalanceAfter = await ethers.provider.getBalance(earningsCollector.address)
        const earningsAmount = mintFeeCost.sub(feeAmount)
        const earningsCollectorExpectedBalanceAfter = earningsCollectorBalanceBefore.add(earningsAmount)
        assert.equal(earningsCollectorExpectedBalanceAfter.toString(), earningsCollectorBalanceAfter.toString(), 'Earnings collector balance is correct.')
    })
    it('Can\'t mint more than mint limit', async () => {
        // Public stage
        await time.increase(86401*3)
        await expect(eeseeNFTDrop.connect(acc2).mint(10, []))
        .to.be.revertedWith('eeseeNFTDrop: You can\'t mint more than mint cap.')
        await expect(eeseeNFTDrop.connect(acc2).mint(5, []))
        .to.emit(eeseeNFTDrop, "Transfer")
        .withArgs('0x0000000000000000000000000000000000000000', acc2.address, 31)
        .to.emit(eeseeNFTDrop, "Transfer")
        .withArgs('0x0000000000000000000000000000000000000000', acc2.address, 35)
        await expect(eeseeNFTDrop.connect(acc2).mint(1, []))
        .to.be.revertedWith('eeseeNFTDrop: You can\'t mint more than mint cap.')
    })
    it('Can\'t mint after mint ended', async () => {
        // Mint ended
        await time.increase(86401)
        await expect(eeseeNFTDrop.connect(acc2).mint(10, []))
        .to.be.revertedWith('eeseeNFTDrop: Mint has already ended.')
    })
    it('Royalty info is correct', async () => {
        for(let i = 1 ; i <= 35; i ++ ){ 
            const royaltyInfo = await eeseeNFTDrop.royaltyInfo(i, 100)
            assert.equal(royaltyInfo[0].toString(), royaltyCollector.address, 'Royalty address reciever is correct')
            assert.equal(royaltyInfo[1].toString(), '3', 'Royalty amount is correct')
        }
    })
});
