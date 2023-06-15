const {
    time,
    loadFixture,
  } = require("@nomicfoundation/hardhat-network-helpers");
  const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
  const { expect } = require("chai");
  const { ethers, network } = require("hardhat");
  const { StandardMerkleTree } = require('@openzeppelin/merkle-tree');
  const assert = require("assert");
  describe("eeseeNFTDrop", function () {
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
    let mockVRF;
    let eesee;
    let eeseeNFTDrop;
    let signer, acc2, acc3, acc4, acc5, acc6, acc7, acc8, feeCollector, royaltyCollector;
    let ticketBuyers;
    let minter;
    let royaltyEninge;
    let currentTimestamp;
    let merkleTreeOfPresale1;
    let leaves = []
    //after one year
    const timeNow = Math.round((new Date()).getTime() / 1000);
    const zeroAddress = "0x0000000000000000000000000000000000000000"
    const oneAddress = "0x0000000000000000000000000000000000000001"
  
    this.beforeAll(async() => {
        [signer, acc2, acc3, acc4, acc5, acc6, acc7, earningsCollector, feeCollector, royaltyCollector] = await ethers.getSigners()
        ticketBuyers = [acc2,acc3, acc4, acc5, acc6,  acc7]
        const _ESE = await hre.ethers.getContractFactory("ESE");
        const _mockVRF = await hre.ethers.getContractFactory("MockVRFCoordinator");
        const _eesee = await hre.ethers.getContractFactory("eesee");
        const _minter = await hre.ethers.getContractFactory("eeseeMinter");
        const _royaltyEngine = await hre.ethers.getContractFactory("MockRoyaltyEngine");
        const _eeseeNFTDrop = await hre.ethers.getContractFactory("eeseeNFTDrop")

        ESE = await _ESE.deploy(
            {
                cliff: 0,
                duration: 0,
                TGEMintShare: 10000,
                beneficiaries: [{addr: signer.address, amount:'1000000000000000000000000'}]
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
                beneficiaries: []
            }
        )
        await ESE.deployed()

        mockVRF = await _mockVRF.deploy()
        await mockVRF.deployed()

        minter = await _minter.deploy('baseURI.com/', 'contractURI.com/')
        await minter.deployed()

        royaltyEninge = await _royaltyEngine.deploy();
        await royaltyEninge.deployed()

        eesee = await _eesee.deploy(
            ESE.address, 
            minter.address, 
            feeCollector.address, 
            royaltyEninge.address, 
            mockVRF.address,
            zeroAddress,//ChainLink token
            '0x0000000000000000000000000000000000000000000000000000000000000000',//Key Hash
            0,//minimumRequestConfirmations
            50000,//callbackGasLimit
            '0x0000000000000000000000000000000000000000'//1inch, does not matter in this test
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
            royaltyCollector.address, 
            300,
            35, 
            currentTimestamp + 86400,
            publicStage,
            presaleStages
        )
        await eeseeNFTDrop.deployed()
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
        await expect(eeseeNFTDrop.connect(signer).mint(acc2.address, 10, []))
        .to.be.revertedWithCustomError(eeseeNFTDrop, 'MintingNotStarted')
    })
    it('Can mint in presale stage if in allowlist', async () => {
        // Presale 1
        await time.increase(86401)
        const invalidMerkleTree = StandardMerkleTree.of([...leaves, [acc3.address]], ['address'])
        await expect(eeseeNFTDrop.connect(signer).mint(acc3.address, 10, getProof(invalidMerkleTree, acc3.address)))
        .to.be.revertedWithCustomError(eeseeNFTDrop, 'NotInAllowlist')
        await expect(eeseeNFTDrop.connect(signer).mint(acc2.address,10, getProof(merkleTreeOfPresale1, acc2.address)))
        .to.emit(eeseeNFTDrop, "Transfer")
        .withArgs('0x0000000000000000000000000000000000000000', acc2.address, 1)
        .to.emit(eeseeNFTDrop, "Transfer")
        .withArgs('0x0000000000000000000000000000000000000000', acc2.address, 10)
    })
    it('Can\'t mint more than per address limit', async () => {
        // Presale 2
        await time.increase(86401)
        await expect(eeseeNFTDrop.connect(signer).mint(acc3.address, 10, []))
        .to.be.revertedWithCustomError(eeseeNFTDrop, 'MintLimitExceeded')
        await expect(eeseeNFTDrop.connect(signer).mint(acc3.address, 5, []))
        .to.emit(eeseeNFTDrop, "Transfer")
        .withArgs('0x0000000000000000000000000000000000000000', acc3.address, 11)
        .to.emit(eeseeNFTDrop, "Transfer")
        .withArgs('0x0000000000000000000000000000000000000000', acc3.address, 15)
        await expect(eeseeNFTDrop.connect(signer).mint(acc3.address, 1, []))
        .to.be.revertedWithCustomError(eeseeNFTDrop, 'MintLimitExceeded')
        await expect(eeseeNFTDrop.connect(signer).mint(acc2.address, 5, []))
        .to.emit(eeseeNFTDrop, "Transfer")
        .withArgs('0x0000000000000000000000000000000000000000', acc2.address, 16)
        .to.emit(eeseeNFTDrop, "Transfer")
        .withArgs('0x0000000000000000000000000000000000000000', acc2.address, 20)
    })
    it('Can\'t mint more than mint limit', async () => {
        // Presale 3
        await time.increase(86401)
        // Public stage
        await time.increase(86401*3)
        await expect(eeseeNFTDrop.connect(signer).mint(acc2.address, 36, []))
        .to.be.revertedWithCustomError(eeseeNFTDrop, 'MintLimitExceeded')
        await expect(eeseeNFTDrop.connect(signer).mint(acc2.address, 5, []))
        .to.emit(eeseeNFTDrop, "Transfer")
        .withArgs('0x0000000000000000000000000000000000000000', acc2.address, anyValue)
        .to.emit(eeseeNFTDrop, "Transfer")
        .withArgs('0x0000000000000000000000000000000000000000', acc2.address, anyValue)
    })
    it('Can\'t mint after mint ended', async () => {
        // Mint ended
        await time.increase(86401)
        await expect(eeseeNFTDrop.connect(signer).mint(acc2.address, 10, []))
        .to.be.revertedWithCustomError(eeseeNFTDrop, 'MintingEnded')
    })
    it('Royalty info is correct', async () => {
        for(let i = 1 ; i <= 35; i ++ ){ 
            const royaltyInfo = await eeseeNFTDrop.royaltyInfo(i, 100)
            assert.equal(royaltyInfo[0].toString(), royaltyCollector.address, 'Royalty address reciever is correct')
            assert.equal(royaltyInfo[1].toString(), '3', 'Royalty amount is correct')
        }
    })

    it('Owner can set mint options', async () => {
        const _eeseeNFTDrop = await hre.ethers.getContractFactory("eeseeNFTDrop")
        currentTimestamp = (await ethers.provider.getBlock()).timestamp;

        await expect(_eeseeNFTDrop.deploy(
            'ABCDFG',
            'ABC',
            '/',
            '/',
            royaltyCollector.address, 
            300,
            35, 
            currentTimestamp - 86400,
            publicStage,
            presaleStages
        )).to.be.revertedWithCustomError(_eeseeNFTDrop, 'MintTimestampNotInFuture')
        await expect(_eeseeNFTDrop.deploy(
            'ABCDFG',
            'ABC',
            '/',
            '/',
            royaltyCollector.address, 
            300,
            35, 
            currentTimestamp + 86400,
            publicStage,
            presalesDuration0
        )).to.be.revertedWithCustomError(_eeseeNFTDrop, 'ZeroSaleStageDuration')
        await expect(_eeseeNFTDrop.deploy(
            'ABCDFG',
            'ABC',
            '/',
            '/',
            royaltyCollector.address, 
            300,
            35, 
            currentTimestamp + 86400,
            publicStage,
            [...presaleStages, presaleStages[0]]
        )).to.be.revertedWithCustomError(_eeseeNFTDrop, 'PresaleStageLimitExceeded')
    })
});
