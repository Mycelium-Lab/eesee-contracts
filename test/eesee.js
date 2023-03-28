const {
    time,
    loadFixture,
  } = require("@nomicfoundation/hardhat-network-helpers");
  const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
  const { expect } = require("chai");
  const { ethers, network } = require("hardhat");
  const assert = require("assert");
  
  describe("eesee", function () {
    let ESE;
    let pool;
    let mockVRF;
    let eesee;
    let NFT;
    let signer, acc2, acc3, acc4;
    //after one year
    const timeNow = Math.round((new Date()).getTime() / 1000);
    const zeroAddress = "0x0000000000000000000000000000000000000000"
  
    this.beforeAll(async() => {
        [signer, acc2, acc3, acc4] = await ethers.getSigners()
        const _ESE = await hre.ethers.getContractFactory("ESE");
        const _pool = await hre.ethers.getContractFactory("eeseePool");
        const _mockVRF = await hre.ethers.getContractFactory("MockVRFCoordinator");
        const _eesee = await hre.ethers.getContractFactory("eesee");
        const _NFT = await hre.ethers.getContractFactory("eeseeNFT");
        
        ESE = await _ESE.deploy('1000000000000000000000000')
        await ESE.deployed()
        await ESE.transfer(acc2.address, '10000000000000000000000')
        
        pool = await _pool.deploy(ESE.address)
        await pool.deployed()

        mockVRF = await _mockVRF.deploy()
        await mockVRF.deployed()

        eesee = await _eesee.deploy(
            ESE.address, 
            pool.address, 
            '', 
            acc4.address, 
            mockVRF.address,
            zeroAddress,//ChainLink token
            '0x0000000000000000000000000000000000000000000000000000000000000000',//Key Hash
            0,//minimumRequestConfirmations
            100000//callbackGasLimit
        )
        await eesee.deployed()

        NFT = await _NFT.deploy("TEST", "TST", '')
        await NFT.deployed()
        await NFT.mint(3)
        await NFT.approve(eesee.address, 1)
        await NFT.approve(eesee.address, 2)
        await NFT.approve(eesee.address, 3)
        await ESE.connect(acc2).approve(eesee.address, '0xfffffffffffffffffffffffffffffffff')
    })

    it('Lists NFT', async () => {
        await expect(eesee.connect(signer).listItem({token: NFT.address, tokenID: 1}, 1, 2, 86400)).to.be.revertedWith("eesee: Max tickets must be more or equal 2")
        await expect(eesee.connect(signer).listItem({token: NFT.address, tokenID: 1}, 100, 0, 86400)).to.be.revertedWith('eesee: Ticket price must be above zero')
        await expect(eesee.connect(signer).listItem({token: NFT.address, tokenID: 1}, 100, 0, 86399)).to.be.revertedWith('eesee: Duration must be more or equal minDuration')
        await expect(eesee.connect(signer).listItem({token: NFT.address, tokenID: 1}, 100, 0, 2592001)).to.be.revertedWith('eesee: Duration must be less or equal maxDuration')
        
        const ID = 1
        await expect(eesee.connect(signer).listItem({token: NFT.address, tokenID: 1}, 100, 2, 86400))
            .to.emit(eesee, "ListItem")
            .withArgs(ID, anyValue, signer.address, 100, 2, 86400)//{token: NFT.address, tokenID: 1} produces wrong hash for some reason

        const listing = await eesee.listings(ID);
        assert.equal(listing.ID.toString(), ID.toString(), "ID is correct")
        assert.equal(listing.nft.token, NFT.address, "NFT is correct")
        assert.equal(listing.nft.tokenID, 1, "NFT tokenID is correct")
        assert.equal(listing.owner, signer.address, "Owner is correct")
        assert.equal(listing.maxTickets, 100, "maxTickets is correct")
        assert.equal(listing.ticketPrice, 2, "ticketPrice is correct")
        assert.equal(listing.ticketsBought, 0, "ticketsBought is correct")
        assert.equal(listing.devFee, '20000000000000000', "devFee is correct")
        assert.equal(listing.poolFee, '80000000000000000', "poolFee is correct")
        //assert.equal(listing.creationTime, timeNow, "creationTime is correct")
        assert.equal(listing.duration, 86400, "duration is correct")
        assert.equal(listing.winner, zeroAddress, "winner is correct")
        assert.equal(listing.chainlinkRequestSent, false, "chainlinkRequestSent is correct")
        assert.equal(listing.itemClaimed, false, "itemClaimed is correct")
        assert.equal(listing.tokensClaimed, false, "tokensClaimed is correct")
    })

    it('Buys tickets', async () => {
        const ID = 1
        await expect(eesee.connect(acc2).buyTickets(ID, 0)).to.be.revertedWith("eesee: Amount must be above zero")
        await expect(eesee.connect(acc2).buyTickets(0, 1)).to.be.revertedWith('eesee: Listing does not exist')
        //await expect(eesee.connect(signer).buyTickets()).to.be.revertedWith('eesee: Listing has already expired')
        //await expect(eesee.connect(signer).buyTickets()).to.be.revertedWith('eesee: Listing fulfilment is already pending')
        //eesee: All tickets bought
        await expect(eesee.connect(acc2).buyTickets(ID, 21)).to.be.revertedWith('eesee: Max tickets bought by this address')

        const balanceBefore = await ESE.balanceOf(acc2.address)
        const recipt = expect(eesee.connect(acc2).buyTickets(ID, 20))
        for (let i = 0; i < 20; i++) {
            await recipt.to.emit(eesee, "BuyTicket").withArgs(ID, acc2.address, i, 2)

            const buyer = await eesee.getListingTicketIDBuyer(ID, i)
            assert.equal(buyer, acc2.address, "Ticket buyer is correct")
        }

        const tickets = await eesee.getListingTicketsBoughtByAddress(ID, acc2.address)
        assert.equal(tickets, 20, "Tickets bought by address is correct")

        const balanceAfter = await ESE.balanceOf(acc2.address)
        assert.equal(BigInt(balanceBefore) - BigInt(balanceAfter), 20*2, "Price paid is correct")

        await expect(eesee.connect(acc2).buyTickets(ID, 1)).to.be.revertedWith("eesee: Max tickets bought by this address")

        const listing = await eesee.listings(ID);
        assert.equal(listing.ticketsBought, 20, "ticketsBought is correct")
    })

    //Buy all tickets and check if RequestWords() event was called, chainlinkRequestSent set to true, chainlinkRequestIDs is set
    //Also, need to check the period between requestRandomWords call and fulfillRandomWords for vulnerabilities
  });
  