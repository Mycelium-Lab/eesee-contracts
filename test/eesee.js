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
    let signer, acc2, acc3, acc4, acc5, acc6, acc7, acc8, feeCollector;
    let ticketBuyers
    //after one year
    const timeNow = Math.round((new Date()).getTime() / 1000);
    const zeroAddress = "0x0000000000000000000000000000000000000000"
  
    this.beforeAll(async() => {
        [signer, acc2, acc3, acc4, acc5, acc6, acc7, acc8, feeCollector] = await ethers.getSigners()
        ticketBuyers = [acc2,acc3, acc4, acc5, acc6,  acc7]
        const _ESE = await hre.ethers.getContractFactory("ESE");
        const _pool = await hre.ethers.getContractFactory("eeseePool");
        const _mockVRF = await hre.ethers.getContractFactory("MockVRFCoordinator");
        const _eesee = await hre.ethers.getContractFactory("eesee");
        const _NFT = await hre.ethers.getContractFactory("eeseeNFT");
        ESE = await _ESE.deploy('1000000000000000000000000')
        await ESE.deployed()
        
        pool = await _pool.deploy(ESE.address)
        await pool.deployed()

        mockVRF = await _mockVRF.deploy()
        await mockVRF.deployed()

        eesee = await _eesee.deploy(
            ESE.address, 
            pool.address, 
            '', 
            feeCollector.address, 
            mockVRF.address,
            zeroAddress,//ChainLink token
            '0x0000000000000000000000000000000000000000000000000000000000000000',//Key Hash
            0,//minimumRequestConfirmations
            50000//callbackGasLimit
        )
        await eesee.deployed()

        NFT = await _NFT.deploy("TEST", "TST", '')
        await NFT.deployed()
        await NFT.mint(4)
        await NFT.approve(eesee.address, 1)
        await NFT.approve(eesee.address, 2)
        await NFT.approve(eesee.address, 3)
        await NFT.approve(eesee.address, 4)

        for (let i = 0; i < ticketBuyers.length; i++) {
            await ESE.transfer(ticketBuyers[i].address, '10000000000000000000000')
            await ESE.connect(ticketBuyers[i]).approve(eesee.address, '10000000000000000000000')
        }

        await ESE.transfer(acc8.address, '100000000000000000000')
        await ESE.connect(acc8).approve(eesee.address, '100000000000000000000')
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

    it('Batch lists NFT', async () => {
        await expect(eesee.connect(signer).listItems(
            [
                { token: NFT.address, tokenID: 2 },
                { token: NFT.address, tokenID: 3 },
                { token: NFT.address, tokenID: 4 }
            ],
            [
                50,
                150,
                200
            ],
            [
                3,
                4,
                5
            ],
            [
                86400,
                86400,
                86400
            ]
        ))
        .to.emit(eesee, "ListItem")
        .withArgs(2, anyValue, signer.address, 50, 3, 86400)
        .and.to.emit(eesee, "ListItem")
        .withArgs(3, anyValue, signer.address, 150, 4, 86400)
        .and.to.emit(eesee, "ListItem")
        .withArgs(4, anyValue, signer.address, 200, 5, 86400)
    })

    it('mints and lists NFT', async () => {
        const fee = BigInt(await eesee.mintFee())

        let feeBalanceBefore = await ESE.balanceOf(feeCollector.address)
        let balanceBefore = await ESE.balanceOf(acc8.address)
        await expect(eesee.connect(acc8).mintAndListItem(
            50,
            3,
            86400,
        ))
        .to.emit(eesee, "ListItem")
        .withArgs(5, anyValue, acc8.address, 50, 3, 86400)
        .and.to.emit(eesee, "CollectDevFee")
        .withArgs(feeCollector.address, fee)

        let feeBalanceAfter = await ESE.balanceOf(feeCollector.address)
        let balanceAfter = await ESE.balanceOf(acc8.address)
        assert.equal(BigInt(balanceBefore) - BigInt(balanceAfter), fee, "Mint fee is correct")
        assert.equal(BigInt(feeBalanceAfter) - BigInt(feeBalanceBefore), fee, "Mint fee is correct")

        feeBalanceBefore = await ESE.balanceOf(feeCollector.address)
        balanceBefore = await ESE.balanceOf(acc8.address)
        await expect(eesee.connect(acc8).mintAndListItems(
            [50, 10, 66],
            [3,4,5],
            [86400, 86401, 86402],
        ))
        .to.emit(eesee, "ListItem")
        .withArgs(6, anyValue, acc8.address, 50, 3, 86400)
        .and.to.emit(eesee, "ListItem")
        .withArgs(7, anyValue, acc8.address, 10, 4, 86401)
        .and.to.emit(eesee, "ListItem")
        .withArgs(8, anyValue, acc8.address, 66, 5, 86402)
        .and.to.emit(eesee, "CollectDevFee")
        .withArgs(feeCollector.address, fee)

        feeBalanceAfter = await ESE.balanceOf(feeCollector.address)
        balanceAfter = await ESE.balanceOf(acc8.address)
        assert.equal(BigInt(balanceBefore) - BigInt(balanceAfter), fee, "Mint fee is correct")
        assert.equal(BigInt(feeBalanceAfter) - BigInt(feeBalanceBefore), fee, "Mint fee is correct")

        feeBalanceBefore = await ESE.balanceOf(feeCollector.address)
        balanceBefore = await ESE.balanceOf(acc8.address)
        await expect(eesee.connect(acc8).mintAndListItemWithDeploy(
            "APES",
            "bayc",
            "/",
            50,
            3,
            86400,
        ))
        .to.emit(eesee, "ListItem")
        .withArgs(9, anyValue, acc8.address, 50, 3, 86400)
        .and.to.emit(eesee, "CollectDevFee")
        .withArgs(feeCollector.address, fee)

        feeBalanceAfter = await ESE.balanceOf(feeCollector.address)
        balanceAfter = await ESE.balanceOf(acc8.address)
        assert.equal(BigInt(balanceBefore) - BigInt(balanceAfter), fee, "Mint fee is correct")
        assert.equal(BigInt(feeBalanceAfter) - BigInt(feeBalanceBefore), fee, "Mint fee is correct")

        feeBalanceBefore = await ESE.balanceOf(feeCollector.address)
        balanceBefore = await ESE.balanceOf(acc8.address)
        await expect(eesee.connect(acc8).mintAndListItemsWithDeploy(
            "APES",
            "bayc",
            "/",
            [50, 10, 66],
            [3,4,5],
            [86400, 86401, 86402],
        ))
        .to.emit(eesee, "ListItem")
        .withArgs(10, anyValue, acc8.address, 50, 3, 86400)
        .and.to.emit(eesee, "ListItem")
        .withArgs(11, anyValue, acc8.address, 10, 4, 86401)
        .and.to.emit(eesee, "ListItem")
        .withArgs(12, anyValue, acc8.address, 66, 5, 86402)
        .and.to.emit(eesee, "CollectDevFee")
        .withArgs(feeCollector.address, fee)
        
        feeBalanceAfter = await ESE.balanceOf(feeCollector.address)
        balanceAfter = await ESE.balanceOf(acc8.address)
        assert.equal(BigInt(balanceBefore) - BigInt(balanceAfter), fee, "Mint fee is correct")
        assert.equal(BigInt(feeBalanceAfter) - BigInt(feeBalanceBefore), fee, "Mint fee is correct")
    })

    it('Buys tickets', async () => {
        const ID = 1
        await expect(eesee.connect(acc2).buyTickets(ID, 0)).to.be.revertedWith("eesee: Amount must be above zero")
        await expect(eesee.connect(acc2).buyTickets(0, 1)).to.be.revertedWith('eesee: Listing does not exist')
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

    it('Buys all tickets', async () => {
        const ID = 1
        for (let i = 1; i <= 4; i++) {
            const balanceBefore = await ESE.balanceOf(ticketBuyers[i].address)
            const recipt = expect(eesee.connect(ticketBuyers[i]).buyTickets(ID, 20))
            for (let j = i * 20; j < (i + 1) * 20; j++) {
                await recipt.to.emit(eesee, "BuyTicket").withArgs(ID, ticketBuyers[i].address, j, 2)

                const buyer = await eesee.getListingTicketIDBuyer(ID, j)
                assert.equal(buyer, ticketBuyers[i].address, "Ticket buyer is correct")
            }

            const tickets = await eesee.getListingTicketsBoughtByAddress(ID, ticketBuyers[i].address)
            assert.equal(tickets, 20, "Tickets bought by address is correct")

            const balanceAfter = await ESE.balanceOf(ticketBuyers[i].address)
            assert.equal(BigInt(balanceBefore) - BigInt(balanceAfter), 20*2, "Price paid is correct")

            await expect(eesee.connect(ticketBuyers[i]).buyTickets(ID, 1)).to.be.revertedWith("eesee: Max tickets bought by this address")

            const listing = await eesee.listings(ID);
            assert.equal(listing.ticketsBought, (i + 1)*20, "ticketsBought is correct")

            await expect(eesee.connect(ticketBuyers[i]).batchReceiveItems([ID], ticketBuyers[i].address))
                .to.be.revertedWith("eesee: Caller is not the winner")
            await expect(eesee.connect(ticketBuyers[i]).batchReceiveTokens([ID], ticketBuyers[i].address))
                .to.be.revertedWith("eesee: Listing is not filfilled")

            await expect(eesee.connect(signer).batchReclaimItems([ID], ticketBuyers[i].address))
                .to.be.revertedWith("eesee: Listing has not expired yet")
            await expect(eesee.connect(ticketBuyers[i]).batchReclaimTokens([ID], ticketBuyers[i].address))
                .to.be.revertedWith("eesee: Listing has not expired yet")

            if(i == 4){
                //MockVRF's first requestID is 0
                await recipt.to.emit(eesee, "RequestWords").withArgs(ID, 0)
                assert.equal(listing.chainlinkRequestSent, true, "chainlinkRequestSent is correct")
            }
        }

        //buy tickets for listing that will expire
        const expiredListingID = 2
        const buyTicketsForExpiredReceipt = expect(eesee.connect(acc7).buyTickets(expiredListingID, 5))
        for(let i = 0; i < 5; i ++) {
            await buyTicketsForExpiredReceipt.to.emit(eesee, "BuyTicket").withArgs(expiredListingID, acc7.address, i, 3)
        }
        
        await expect(eesee.connect(ticketBuyers[5]).buyTickets(ID, 1)).to.be.revertedWith("eesee: All tickets bought")
    })

    it('Selects winner', async () => {
        const ID = 1
        const recipt = expect(mockVRF.fulfillWords(0))

        const listing = await eesee.listings(ID);
        assert.notEqual(listing.winner, zeroAddress, "winner is chosen")

        await recipt.to.emit(eesee, "FulfillListing").withArgs(ID, anyValue, listing.winner)//{token: NFT.address, tokenID: 1} produces wrong hash for some reason
    })

    //also check batch receive multiple at the same time
    it('Receives item after win', async () => {
        const ID = 1
        let listing = await eesee.listings(ID)
        const signers = await ethers.getSigners()
        const winnerAcc = signers.filter(signer => signer.address === listing.winner)[0]
        const notWinnerAcc = signers.filter(signer => signer.address !== listing.winner)[0]
        await expect(eesee.connect(notWinnerAcc).batchReceiveItems([ID], listing.winner))
        .to.be.revertedWith("eesee: Caller is not the winner")
        await expect(eesee.connect(winnerAcc).batchReceiveItems([ID], listing.winner))
        .to.emit(eesee, "ReceiveItem")
        .withArgs(ID, anyValue, listing.winner)
        listing = await eesee.listings(ID)
        assert.equal(listing.itemClaimed, true, "itemClaimed is correct")
        assert.equal(listing.tokensClaimed, false, "tokensClaimed is correct")
        assert.equal(listing.chainlinkRequestSent, true, "chainlinkRequestSent is correct")
        const owner = await NFT.ownerOf(ID)
        assert.equal(owner, listing.winner, "new owner of NFT is correct")
        await expect(eesee.connect(winnerAcc).batchReceiveItems([ID], listing.winner))
        .to.be.revertedWith("eesee: Item has already been claimed")
    })
    it('Receives tokens',  async () => {
        const ID = 1
        await expect(eesee.connect(acc2).batchReceiveTokens([ID], acc2.address))
        .to.be.revertedWith("eesee: Caller is not the owner")

        const listing = await eesee.listings(ID);
        const expectedDevFee = BigInt(listing.ticketPrice) * BigInt(listing.maxTickets) * BigInt(listing.devFee) / BigInt('1000000000000000000')
        const expectedPoolFee = BigInt(listing.ticketPrice) * BigInt(listing.maxTickets) * BigInt(listing.poolFee) / BigInt('1000000000000000000')
        const expectedReceive = BigInt(listing.ticketPrice) * BigInt(listing.maxTickets) - expectedDevFee - expectedPoolFee

        const ownerBalanceBefore = await ESE.balanceOf(signer.address)
        const feeBalanceBefore = await ESE.balanceOf(feeCollector.address)
        const poolBalanceBefore = await ESE.balanceOf(pool.address)
        await expect(eesee.connect(signer).batchReceiveTokens([ID], signer.address))
        .to.emit(eesee, "ReceiveTokens")
        .withArgs(ID, signer.address, expectedReceive)
        .and.to.emit(eesee, "CollectDevFee")
        .withArgs(feeCollector.address, expectedDevFee)
        .and.to.emit(eesee, "CollectPoolFee")
        .withArgs(pool.address, expectedPoolFee)
        const ownerBalanceAfter = await ESE.balanceOf(signer.address)
        const feeBalanceAfter = await ESE.balanceOf(feeCollector.address)
        const poolBalanceAfter = await ESE.balanceOf(pool.address)

        assert.equal(expectedDevFee, BigInt(feeBalanceAfter) - BigInt(feeBalanceBefore), "devFee is correct")
        assert.equal(expectedPoolFee, BigInt(poolBalanceAfter) - BigInt(poolBalanceBefore), "poolFee is correct")
        assert.equal(expectedReceive, BigInt(ownerBalanceAfter) - BigInt(ownerBalanceBefore), "owner balance is correct")

        // reverted with eesee: Listing is not filfilled because listing deleted after previous claim
        await expect(eesee.connect(signer).batchReceiveTokens([ID], signer.address))
        .to.be.revertedWith("eesee: Listing is not filfilled")
    })
    it('buyTickets reverts if listing is expired', async () => {
        const IDs = [2,3,4]

        await eesee.connect(acc2).buyTickets(IDs[2], 20)

        const timestampBeforeTimeSkip = (await ethers.provider.getBlock()).timestamp
        await time.increase(86401)
        const timestampAfterTimeSkip = (await ethers.provider.getBlock()).timestamp
        const listing = await eesee.listings(IDs[0])
        assert.equal(timestampBeforeTimeSkip, timestampAfterTimeSkip-86401, "timetravel is successfull")
        assert.equal((listing.creationTime.add(listing.duration)).lt(timestampAfterTimeSkip), true, "listing expired")
        await expect(eesee.connect(acc2).buyTickets(IDs[0], 20)).to.be.revertedWith("eesee: Listing has already expired")
        await expect(eesee.connect(acc2).buyTickets(IDs[1], 20)).to.be.revertedWith("eesee: Listing has already expired")
    })
    it('Can reclaim tokens if listing is expired', async () => {
        const expiredListingID = 2
        const listing = await eesee.listings(expiredListingID)
        await expect(eesee.connect(acc7).batchReclaimTokens([expiredListingID], acc7.address))
        .to.emit(eesee, "ReclaimTokens")
        .withArgs(expiredListingID, acc7.address, acc7.address, 5, listing.ticketPrice.mul(ethers.BigNumber.from(5))) //emit ReclaimTokens(ID, msg.sender, recipient, ticketsBoughtByAddress, _amount);
    })
    it('Can reclaim item if listing is expired', async () => {
        const IDs = [2,3,4]
        await expect(eesee.connect(acc2).batchReclaimItems(IDs, signer.address))
        .to.be.revertedWith("eesee: Caller is not the owner")
        await expect(eesee.connect(signer).batchReclaimItems(IDs, signer.address))
        .to.emit(eesee, "ReclaimItem")
        .withArgs(2, anyValue, signer.address)
        .and.to.emit(eesee, "ReclaimItem")
        .withArgs(3, anyValue, signer.address)
        .and.to.emit(eesee, "ReclaimItem")
        .withArgs(4, anyValue, signer.address)

        await expect(eesee.connect(signer).batchReclaimItems([4], signer.address))
            .to.be.revertedWith("eesee: Item has already been claimed")
    })
    
    it('Changes constants', async () => {
        let newValue = 1
        const minDuration = await eesee.minDuration() 
        await expect(eesee.connect(acc2).changeMinDuration(newValue)).to.be.revertedWith("Ownable: caller is not the owner")
        await expect(eesee.connect(signer).changeMinDuration(newValue))
        .to.emit(eesee, "ChangeMinDuration")
        .withArgs(minDuration, newValue)
        assert.equal(newValue, await eesee.minDuration(), "minDuration has changed")

        const maxDuration = await eesee.maxDuration() 
        await expect(eesee.connect(acc2).changeMaxDuration(newValue)).to.be.revertedWith("Ownable: caller is not the owner")
        await expect(eesee.connect(signer).changeMaxDuration(newValue))
        .to.emit(eesee, "ChangeMaxDuration")
        .withArgs(maxDuration, newValue)
        assert.equal(newValue, await eesee.maxDuration(), "maxDuration has changed")

        const maxTicketsBoughtByAddress = await eesee.maxTicketsBoughtByAddress() 
        await expect(eesee.connect(acc2).changeMaxTicketsBoughtByAddress(newValue)).to.be.revertedWith("Ownable: caller is not the owner")
        await expect(eesee.connect(signer).changeMaxTicketsBoughtByAddress('1000000000000000001')).to.be.revertedWith("eesee: Can't set maxTicketsBoughtByAddress to more than 100%")
        await expect(eesee.connect(signer).changeMaxTicketsBoughtByAddress(newValue))
        .to.emit(eesee, "ChangeMaxTicketsBoughtByAddress")
        .withArgs(maxTicketsBoughtByAddress, newValue)
        assert.equal(newValue, await eesee.maxTicketsBoughtByAddress(), "maxTicketsBoughtByAddress has changed")

        const mintFee = await eesee.mintFee() 
        await expect(eesee.connect(acc2).changeMintFee(newValue)).to.be.revertedWith("Ownable: caller is not the owner")
        await expect(eesee.connect(signer).changeMintFee(newValue))
        .to.emit(eesee, "ChangeMintFee")
        .withArgs(mintFee, newValue)
        assert.equal(newValue, await eesee.mintFee(), "mintFee has changed")

        const devFee = await eesee.devFee() 
        await expect(eesee.connect(acc2).changeDevFee(newValue)).to.be.revertedWith("Ownable: caller is not the owner")
        //poolFee is 80000000000000000 now so poolFee + devFee > 40%
        await expect(eesee.connect(signer).changeDevFee('330000000000000000')).to.be.revertedWith("eesee: Can't set fees to more than 40%")
        await expect(eesee.connect(signer).changeDevFee(newValue))
        .to.emit(eesee, "ChangeDevFee")
        .withArgs(devFee, newValue)
        assert.equal(newValue, await eesee.devFee(), "devFee has changed")

        const poolFee = await eesee.poolFee() 
        await expect(eesee.connect(acc2).changePoolFee(newValue)).to.be.revertedWith("Ownable: caller is not the owner")
        await expect(eesee.connect(signer).changePoolFee('400000000000000000')).to.be.revertedWith("eesee: Can't set fees to more than 40%")
        await expect(eesee.connect(signer).changePoolFee(newValue))
        .to.emit(eesee, "ChangePoolFee")
        .withArgs(poolFee, newValue)
        assert.equal(newValue, await eesee.poolFee(), "poolFee has changed")

        newValue = zeroAddress
        const _feeCollector = await eesee.feeCollector() 
        await expect(eesee.connect(acc2).changeFeeCollector(newValue)).to.be.revertedWith("Ownable: caller is not the owner")
        await expect(eesee.connect(signer).changeFeeCollector(newValue))
        .to.emit(eesee, "ChangeFeeCollector")
        .withArgs(_feeCollector, newValue)
        assert.equal(newValue, await eesee.feeCollector(), "feeCollector has changed")
    })
});
