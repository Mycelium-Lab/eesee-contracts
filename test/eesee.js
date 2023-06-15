const {
    time,
    loadFixture,
  } = require("@nomicfoundation/hardhat-network-helpers");
  const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
  const { expect } = require("chai");
  const { ethers, network } = require("hardhat");
  const assert = require("assert");
  const { StandardMerkleTree } = require('@openzeppelin/merkle-tree');
  describe("eesee", function () {
    let ESE;
    let ERC20;
    let mockVRF;
    let eesee;
    let NFT;
    let signer, acc2, acc3, acc4, acc5, acc6, acc7, acc8, acc9, feeCollector;
    let ticketBuyers;
    let minter;
    let royaltyEninge;
    let mock1InchExecutor
    let mock1InchRouter
    //after one year
    const zeroAddress = "0x0000000000000000000000000000000000000000"
    const oneAddress = "0x0000000000000000000000000000000000000001"
  
    this.beforeAll(async() => {
        [signer, acc2, acc3, acc4, acc5, acc6, acc7, acc8, acc9, feeCollector, royaltyCollector] = await ethers.getSigners()
        ticketBuyers = [acc2,acc3, acc4, acc5, acc6,  acc7]
        const _ESE = await hre.ethers.getContractFactory("ESE");
        const _MockERC20 = await hre.ethers.getContractFactory("MockERC20");
        const _mockVRF = await hre.ethers.getContractFactory("MockVRFCoordinator");
        const _eesee = await hre.ethers.getContractFactory("eesee");
        const _NFT = await hre.ethers.getContractFactory("eeseeNFT");
        const _minter = await hre.ethers.getContractFactory("eeseeMinter");
        const _royaltyEngine = await hre.ethers.getContractFactory("MockRoyaltyEngine");
        const _mock1InchExecutor = await hre.ethers.getContractFactory("Mock1InchExecutor");
        const _mock1InchRouter = await hre.ethers.getContractFactory("Mock1InchRouter");

        ESE = await _ESE.deploy(
            {
                cliff: 0,
                duration: 0,
                TGEMintShare: 10000,
                beneficiaries: [{addr: signer.address, amount: '2000000000000000000000000'}]
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

        ERC20 = await _MockERC20.deploy('2000000000000000000000000')
        await ERC20.deployed()

        mockVRF = await _mockVRF.deploy()
        await mockVRF.deployed()

        minter = await _minter.deploy('baseURI.com/', 'contractURI.com/')
        await minter.deployed()

        royaltyEninge = await _royaltyEngine.deploy();
        await royaltyEninge.deployed()

        mock1InchExecutor = await _mock1InchExecutor.deploy(ESE.address);
        await mock1InchExecutor.deployed()
        await ESE.transfer(mock1InchExecutor.address, '1000000000000000000000000')
        await ERC20.transfer(mock1InchExecutor.address, '1000000000000000000000000')

        mock1InchRouter = await _mock1InchRouter.deploy();
        await mock1InchRouter.deployed()

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
            mock1InchRouter.address
        )
        await eesee.deployed()
        NFT = await _NFT.deploy("TEST", "TST", '', '')
        await NFT.deployed()
        await NFT.mint(signer.address, 4)
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
        await expect(eesee.connect(signer).listItem({collection: NFT.address, tokenID: 1}, 1, 2, 86400)).to.be.revertedWithCustomError(eesee, "MaxTicketsTooLow")
        await expect(eesee.connect(signer).listItem({collection: NFT.address, tokenID: 1}, 100, 0, 86400)).to.be.revertedWithCustomError(eesee, "TicketPriceTooLow")
        await expect(eesee.connect(signer).listItem({collection: NFT.address, tokenID: 1}, 100, 0, 86399)).to.be.revertedWithCustomError(eesee, "DurationTooLow").withArgs(86400)
        await expect(eesee.connect(signer).listItem({collection: NFT.address, tokenID: 1}, 100, 0, 2592001)).to.be.revertedWithCustomError(eesee, "DurationTooHigh").withArgs(2592000)
        
        const ID = 1
        await expect(eesee.connect(signer).listItem({collection: NFT.address, tokenID: 1}, 100, 2, 86400))
            .to.emit(eesee, "ListItem")
            .withArgs(ID, anyValue, signer.address, 100, 2, 86400)//{collection: NFT.address, tokenID: 1} produces wrong hash for some reason

        const listing = await eesee.listings(ID);
        assert.equal(listing.ID.toString(), ID.toString(), "ID is correct")
        assert.equal(listing.nft.collection, NFT.address, "NFT is correct")
        assert.equal(listing.nft.tokenID, 1, "NFT tokenID is correct")
        assert.equal(listing.owner, signer.address, "Owner is correct")
        assert.equal(listing.maxTickets, 100, "maxTickets is correct")
        assert.equal(listing.ticketPrice, 2, "ticketPrice is correct")
        assert.equal(listing.ticketsBought, 0, "ticketsBought is correct")
        assert.equal(listing.fee, '60000000000000000', "fee is correct")
        //assert.equal(listing.creationTime, timeNow, "creationTime is correct")
        assert.equal(listing.duration, 86400, "duration is correct")
        assert.equal(listing.winner, zeroAddress, "winner is correct")
        assert.equal(listing.itemClaimed, false, "itemClaimed is correct")
        assert.equal(listing.tokensClaimed, false, "tokensClaimed is correct")
    })

    it('Batch lists NFT', async () => {
        await expect(eesee.connect(signer).listItems(
            [
                { collection: NFT.address, tokenID: 2 },
                { collection: NFT.address, tokenID: 3 },
                { collection: NFT.address, tokenID: 4 }
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
        await expect(eesee.connect(acc8).mintAndListItem(
            '1/',
            50,
            3,
            86400,
            acc8.address,
            300
        ))
        .to.emit(eesee, "ListItem")
        .withArgs(5, anyValue, acc8.address, 50, 3, 86400)

        await expect(eesee.connect(acc8).mintAndListItems(
            ['2/', '3/', '4/'],
            [50, 10, 66],
            [3,4,5],
            [86400, 86401, 86402],
            acc8.address,
            300
        ))
        .to.emit(eesee, "ListItem")
        .withArgs(6, anyValue, acc8.address, 50, 3, 86400)
        .and.to.emit(eesee, "ListItem")
        .withArgs(7, anyValue, acc8.address, 10, 4, 86401)
        .and.to.emit(eesee, "ListItem")
        .withArgs(8, anyValue, acc8.address, 66, 5, 86402)

        await expect(eesee.connect(acc8).mintAndListItemWithDeploy(
            "APES",
            "bayc",
            "/",
            '/',
            50,
            3,
            86400,
            acc8.address,
            300
        ))
        .to.emit(eesee, "ListItem")
        .withArgs(9, anyValue, acc8.address, 50, 3, 86400)

        await expect(eesee.connect(acc8).mintAndListItemsWithDeploy(
            "APES",
            "bayc",
            "/",
            '/',
            [50, 10, 66],
            [3,4,5],
            [86400, 86401, 86402],
            acc8.address,
            300
        ))
        .to.emit(eesee, "ListItem")
        .withArgs(10, anyValue, acc8.address, 50, 3, 86400)
        .and.to.emit(eesee, "ListItem")
        .withArgs(11, anyValue, acc8.address, 10, 4, 86401)
        .and.to.emit(eesee, "ListItem")
        .withArgs(12, anyValue, acc8.address, 66, 5, 86402)
    })

    it('Buys tickets', async () => {
        const ID = 1
        await expect(eesee.connect(acc2).buyTickets(ID, 0)).to.be.revertedWithCustomError(eesee, "BuyAmountTooLow")
        await expect(eesee.connect(acc2).buyTickets(0, 1)).to.be.revertedWithCustomError(eesee, "ListingNotExists").withArgs(0);
        await expect(eesee.connect(acc2).buyTickets(ID, 21)).to.be.revertedWithCustomError(eesee, "MaxTicketsBoughtByAddress").withArgs(acc2.address);

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

        await expect(eesee.connect(acc2).buyTickets(ID, 1)).to.be.revertedWithCustomError(eesee, "MaxTicketsBoughtByAddress").withArgs(acc2.address)

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

            await expect(eesee.connect(ticketBuyers[i]).buyTickets(ID, 1)).to.be.revertedWithCustomError(eesee, "MaxTicketsBoughtByAddress").withArgs(ticketBuyers[i].address)

            const listing = await eesee.listings(ID);
            assert.equal(listing.ticketsBought, (i + 1)*20, "ticketsBought is correct")

            await expect(eesee.connect(ticketBuyers[i]).batchReceiveItems([ID], ticketBuyers[i].address))
                .to.be.revertedWithCustomError(eesee, "CallerNotWinner").withArgs(ID)
            await expect(eesee.connect(ticketBuyers[i]).batchReceiveTokens([ID], ticketBuyers[i].address))
                .to.be.revertedWithCustomError(eesee, "ListingNotFulfilled").withArgs(ID)

            await expect(eesee.connect(signer).batchReclaimItems([ID], ticketBuyers[i].address))
                .to.be.revertedWithCustomError(eesee, "ListingNotExpired").withArgs(ID)
            await expect(eesee.connect(ticketBuyers[i]).batchReclaimTokens([ID], ticketBuyers[i].address))
                .to.be.revertedWithCustomError(eesee, "ListingNotExpired").withArgs(ID)

            if(i == 4){
                //MockVRF's first requestID is 0
                await recipt.to.emit(eesee, "RequestWords").withArgs(ID, 0)
            }
        }

        //buy tickets for listing that will expire
        const expiredListingID = 2
        const buyTicketsForExpiredReceipt = expect(eesee.connect(acc7).buyTickets(expiredListingID, 5))
        for(let i = 0; i < 5; i ++) {
            await buyTicketsForExpiredReceipt.to.emit(eesee, "BuyTicket").withArgs(expiredListingID, acc7.address, i, 3)
        }
        
        await expect(eesee.connect(ticketBuyers[5]).buyTickets(ID, 1)).to.be.revertedWithCustomError(eesee, "AllTicketsBought")
    })

    it('Selects winner', async () => {
        const ID = 1
        const recipt = expect(await mockVRF.fulfillWords(0))

        const listing = await eesee.listings(ID);
        assert.notEqual(listing.winner, zeroAddress, "winner is chosen")

        await recipt.to.emit(eesee, "FulfillListing").withArgs(ID, anyValue, listing.winner)//{collection: NFT.address, tokenID: 1} produces wrong hash for some reason
    })

    //also check batch receive multiple at the same time
    it('Receives item after win', async () => {
        const ID = 1
        let listing = await eesee.listings(ID)
        const signers = await ethers.getSigners()
        const winnerAcc = signers.filter(signer => signer.address === listing.winner)[0]
        const notWinnerAcc = signers.filter(signer => signer.address !== listing.winner)[0]
        await expect(eesee.connect(notWinnerAcc).batchReceiveItems([ID], listing.winner))
        .to.be.revertedWithCustomError(eesee, "CallerNotWinner").withArgs(ID)
        await expect(eesee.connect(winnerAcc).batchReceiveItems([ID], listing.winner))
        .to.emit(eesee, "ReceiveItem")
        .withArgs(ID, anyValue, listing.winner)
        listing = await eesee.listings(ID)
        assert.equal(listing.itemClaimed, true, "itemClaimed is correct")
        assert.equal(listing.tokensClaimed, false, "tokensClaimed is correct")
        const owner = await NFT.ownerOf(ID)
        assert.equal(owner, listing.winner, "new owner of NFT is correct")
        await expect(eesee.connect(winnerAcc).batchReceiveItems([ID], listing.winner))
        .to.be.revertedWithCustomError(eesee, "ItemAlreadyClaimed").withArgs(ID)
    })
    it('Receives tokens',  async () => {
        const ID = 1
        await expect(eesee.connect(acc2).batchReceiveTokens([ID], acc2.address))
        .to.be.revertedWithCustomError(eesee, "CallerNotOwner").withArgs(ID)

        const listing = await eesee.listings(ID);
        const expectedFee = BigInt(listing.ticketPrice) * BigInt(listing.maxTickets) * BigInt(listing.fee) / BigInt('1000000000000000000')
        const expectedReceive = BigInt(listing.ticketPrice) * BigInt(listing.maxTickets) - expectedFee

        const ownerBalanceBefore = await ESE.balanceOf(signer.address)
        const feeBalanceBefore = await ESE.balanceOf(feeCollector.address)
        await expect(eesee.connect(signer).batchReceiveTokens([ID], signer.address))
        .to.emit(eesee, "ReceiveTokens")
        .withArgs(ID, signer.address, expectedReceive)
        .and.to.emit(eesee, "CollectFee")
        .withArgs(feeCollector.address, expectedFee)
        const ownerBalanceAfter = await ESE.balanceOf(signer.address)
        const feeBalanceAfter = await ESE.balanceOf(feeCollector.address)

        assert.equal(expectedFee, BigInt(feeBalanceAfter) - BigInt(feeBalanceBefore), "fee is correct")
        assert.equal(expectedReceive, BigInt(ownerBalanceAfter) - BigInt(ownerBalanceBefore), "owner balance is correct")

        // reverted with eesee: Listing is not filfilled because listing deleted after previous claim
        await expect(eesee.connect(signer).batchReceiveTokens([ID], signer.address))
        .to.be.revertedWithCustomError(eesee, "ListingNotFulfilled").withArgs(ID)
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
        await expect(eesee.connect(acc2).buyTickets(IDs[0], 20)).to.be.revertedWithCustomError(eesee, "ListingExpired").withArgs(IDs[0])
        await expect(eesee.connect(acc2).buyTickets(IDs[1], 20)).to.be.revertedWithCustomError(eesee, "ListingExpired").withArgs(IDs[1])
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
        .to.be.revertedWithCustomError(eesee, "CallerNotOwner").withArgs(2)
        await expect(eesee.connect(signer).batchReclaimItems(IDs, signer.address))
        .to.emit(eesee, "ReclaimItem")
        .withArgs(2, anyValue, signer.address)
        .and.to.emit(eesee, "ReclaimItem")
        .withArgs(3, anyValue, signer.address)
        .and.to.emit(eesee, "ReclaimItem")
        .withArgs(4, anyValue, signer.address)

        await expect(eesee.connect(signer).batchReclaimItems([4], signer.address))
            .to.be.revertedWithCustomError(eesee, "ItemAlreadyClaimed").withArgs(4)
    })
    it('Royalties work for public collections', async () => {
        const currentListingID = (await eesee.getListingsLength()).toNumber()
        await expect(eesee.connect(acc8).mintAndListItem(
            '5/',
            10,
            10,
            86400,
            royaltyCollector.address,
            200
        ))
        .to.emit(eesee, "ListItem")
        .withArgs(currentListingID, anyValue, acc8.address, 10, 10, 86400)
        
        await expect(eesee.connect(acc8).mintAndListItems(
            ['6/','7/'],
            [5, 10],
            [5,5],
            [86400, 86401],
            royaltyCollector.address,
            500
        ))
        .to.emit(eesee, "ListItem")
        .withArgs(currentListingID + 1, anyValue, acc8.address, 5, 5, 86400)
        .and.to.emit(eesee, "ListItem")
        .withArgs(currentListingID + 2, anyValue, acc8.address, 10, 5, 86401)

        const publicNFTCollectionAddress = await minter.publicCollection()
        const NFT = await ethers.getContractFactory("eeseeNFT")
        const publicNFTCollectionContract = await NFT.attach(publicNFTCollectionAddress)

        assert.equal(await publicNFTCollectionContract.name(), "ESE Public Collection", 'Public collection name is correct')
        assert.equal(await publicNFTCollectionContract.symbol(), "ESE-Public", 'Public collection symbol is correct')
        assert.equal(await publicNFTCollectionContract.URI(), "baseURI.com/", 'Public collection baseURI is correct')
        assert.equal(await publicNFTCollectionContract.tokenURI(1), "1/", 'Public collection tokenURI is correct')
        assert.equal(await publicNFTCollectionContract.contractURI(), "contractURI.com/", 'Public collection contractURI is correct')

        assert.equal(await publicNFTCollectionContract.supportsInterface('0x01ffc9a7'), true, 'collection supports ERC165')
        assert.equal(await publicNFTCollectionContract.supportsInterface('0x80ac58cd'), true, 'collection supports ERC721')
        assert.equal(await publicNFTCollectionContract.supportsInterface('0x5b5e139f'), true, 'collection supports ERC721Metadata')
        assert.equal(await publicNFTCollectionContract.supportsInterface('0x2a55205a'), true, 'collection supports ERC2981')

        const listing1 = await eesee.listings(currentListingID)
        const listing2 = await eesee.listings(currentListingID + 1)
        const listing3 = await eesee.listings(currentListingID + 2)
        const royaltyInfoForListing1 = await publicNFTCollectionContract.royaltyInfo(listing1.nft.tokenID, 100)
        const royaltyInfoForListing2 = await publicNFTCollectionContract.royaltyInfo(listing2.nft.tokenID, 300)
        const royaltyInfoForListing3 = await publicNFTCollectionContract.royaltyInfo(listing3.nft.tokenID, 300)
        assert.equal(royaltyInfoForListing1[1].toString(), "2", `royaltyInfo for ${currentListingID + 1} is correct`)
        assert.equal(royaltyInfoForListing2[1].toString(), "15", `royaltyInfo for ${currentListingID + 2} is correct`)
        assert.equal(royaltyInfoForListing3[1].toString(), "15", `royaltyInfo for ${currentListingID + 3} is correct`)
        
        for(let i = 0; i < 5; i ++){
            await expect(eesee.connect(ticketBuyers[i]).buyTickets(currentListingID, 2))
            .to.emit(eesee, "BuyTicket").withArgs(currentListingID, ticketBuyers[i].address, i*2, 10)
        }
       
        await expect(mockVRF.fulfillWords(1)).to.emit(eesee, "FulfillListing")
        const listing = await eesee.listings(currentListingID);
        assert.notEqual(listing.winner, zeroAddress, "winner is chosen")
        let royaltyCollectorBalanceBefore = await ESE.balanceOf(royaltyCollector.address)
        await expect(eesee.connect(acc8).batchReceiveTokens([currentListingID], acc8.address))
        .to.emit(eesee, 'CollectRoyalty')
        .withArgs(royaltyCollector.address, royaltyInfoForListing1[1])
        let royaltyCollectorBalanceAfter = await ESE.balanceOf(royaltyCollector.address)

        assert.equal(royaltyCollectorBalanceBefore.add(royaltyInfoForListing1[1]).toString(), royaltyCollectorBalanceAfter.toString(), 'Royalty collector balance is correct')
    })
    it('Royalties work for private collections', async () => {
        const currentListingID = (await eesee.getListingsLength()).toNumber()
        await expect(eesee.connect(acc8).mintAndListItemWithDeploy(
            "APES",
            "bayc",
            "/",
            '/',
            5,
            30,
            86400,
            royaltyCollector.address,
            100
        ))
        .to.emit(eesee, "ListItem")
        .withArgs(currentListingID, anyValue, acc8.address, 5, 30, 86400)
        const listing1 = await eesee.listings(currentListingID)
        const collection1 = NFT.attach(listing1.nft.collection)
        const royaltyInfoForListing1 = await collection1.royaltyInfo(listing1.nft.tokenID, 150) 
        assert.equal(royaltyInfoForListing1[1].toString(), "1", `royaltyInfo for ${currentListingID} is correct`)
        await expect(eesee.connect(acc8).mintAndListItemsWithDeploy(
            "APES",
            "bayc",
            "base/",
            'contract/',
            [50, 10],
            [3,4],
            [86400, 86401],
            royaltyCollector.address,
            300
        ))
        .to.emit(eesee, "ListItem")
        .withArgs(currentListingID + 1, anyValue, acc8.address, 50, 3, 86400)
        .and.to.emit(eesee, "ListItem")
        .withArgs(currentListingID + 2, anyValue, acc8.address, 10, 4, 86401)

        const listing2 = await eesee.listings(currentListingID + 1)
        const listing3 = await eesee.listings(currentListingID + 2)
        const collection2 = NFT.attach(listing2.nft.collection)

        assert.equal(await collection2.name(), "APES", 'collection name is correct')
        assert.equal(await collection2.symbol(), "bayc", 'collection symbol is correct')
        assert.equal(await collection2.URI(), "base/", 'collection baseURI is correct')
        assert.equal(await collection2.tokenURI(1), "base/1", 'collection tokenURI is correct')
        assert.equal(await collection2.contractURI(), "contract/", 'collection contractURI is correct')

        assert.equal(await collection2.supportsInterface('0x01ffc9a7'), true, 'collection supports ERC165')
        assert.equal(await collection2.supportsInterface('0x80ac58cd'), true, 'collection supports ERC721')
        assert.equal(await collection2.supportsInterface('0x5b5e139f'), true, 'collection supports ERC721Metadata')
        assert.equal(await collection2.supportsInterface('0x2a55205a'), true, 'collection supports ERC2981')

        const royaltyInfoForListing2 = await collection2.royaltyInfo(listing2.nft.tokenID, 100) 
        const royaltyInfoForListing3 = await collection2.royaltyInfo(listing3.nft.tokenID, 100) 
        assert.equal(royaltyInfoForListing2[1].toString(), "3", `royaltyInfo for ${currentListingID + 1} is correct`)
        assert.equal(royaltyInfoForListing3[1].toString(), "3", `royaltyInfo for ${currentListingID + 2} is correct`)
        for(let i = 0; i < 5; i ++){
            await expect(eesee.connect(ticketBuyers[i]).buyTickets(currentListingID, 1))
            .to.emit(eesee, "BuyTicket").withArgs(currentListingID, ticketBuyers[i].address, i, 30)
        }
       
        await expect(mockVRF.fulfillWords(2)).to.emit(eesee, "FulfillListing")
        const listing = await eesee.listings(currentListingID);
        assert.notEqual(listing.winner, zeroAddress, "winner is chosen")
        let royaltyCollectorBalanceBefore = await ESE.balanceOf(royaltyCollector.address)
        await expect(eesee.connect(acc8).batchReceiveTokens([currentListingID], acc8.address))
        .to.emit(eesee, 'CollectRoyalty')
        .withArgs(royaltyCollector.address, royaltyInfoForListing1[1])
        let royaltyCollectorBalanceAfter = await ESE.balanceOf(royaltyCollector.address)
        assert.equal(royaltyCollectorBalanceBefore.add(royaltyInfoForListing1[1]).toString(), royaltyCollectorBalanceAfter.toString(), 'Royalty collector balance is correct')
    })

    it('swaps tokens using 1inch', async () => {
        const currentListingID = (await eesee.getListingsLength()).toNumber()
        await eesee.connect(signer).mintAndListItem(
            'contract/',
            10,
            50,
            86400,
            royaltyCollector.address,
            300
        )

        await ERC20.approve(eesee.address, '232')

        let iface = new ethers.utils.Interface([
            'function swap(address executor, tuple(address srcToken, address dstToken, address srcReceiver, address dstReceiver, uint amount, uint minReturnAmount, uint flags) desc, bytes permit, bytes data)',
            'function swep(address executor, tuple(address srcToken, address dstToken, address srcReceiver, address dstReceiver, uint amount, uint minReturnAmount, uint flags) desc, bytes permit, bytes data)'
        ]);
        
        let swapData = iface.encodeFunctionData('swap', [
            mock1InchExecutor.address, 
            {
                srcToken: ESE.address,//
                dstToken: ESE.address,
                srcReceiver: mock1InchExecutor.address,
                dstReceiver: eesee.address, 
                amount: 232, 
                minReturnAmount: 100,
                flags: 0,
            }, 
            '0x00',
            '0x000000000000000000000000' + ERC20.address.substring(2)
        ])
        await expect(eesee.connect(signer).buyTicketsWithSwap(currentListingID, swapData))
        .to.be.revertedWithCustomError(eesee, "InvalidSwapDescription")

        swapData = iface.encodeFunctionData('swap', [
            mock1InchExecutor.address, 
            {
                srcToken: ERC20.address,
                dstToken: ERC20.address,//
                srcReceiver: mock1InchExecutor.address,
                dstReceiver: eesee.address,
                amount: 232,
                minReturnAmount: 100,
                flags: 0,
            }, 
            '0x00',
            '0x000000000000000000000000' + ERC20.address.substring(2)
        ])
        await expect(eesee.connect(signer).buyTicketsWithSwap(currentListingID, swapData))
        .to.be.revertedWithCustomError(eesee, "InvalidSwapDescription")

        swapData = iface.encodeFunctionData('swap', [
            mock1InchExecutor.address, 
            {
                srcToken: ERC20.address,
                dstToken: ESE.address,
                srcReceiver: mock1InchExecutor.address,
                dstReceiver: ERC20.address, //
                amount: 232,
                minReturnAmount: 100,
                flags: 0,
            }, 
            '0x00',
            '0x000000000000000000000000' + ERC20.address.substring(2)
        ])
        await expect(eesee.connect(signer).buyTicketsWithSwap(currentListingID, swapData))
        .to.be.revertedWithCustomError(eesee, "InvalidSwapDescription")

        swapData = iface.encodeFunctionData('swep', [//
            mock1InchExecutor.address, 
            {
                srcToken: ERC20.address,
                dstToken: ESE.address,
                srcReceiver: mock1InchExecutor.address,
                dstReceiver: eesee.address, 
                amount: 232,
                minReturnAmount: 100,
                flags: 0,
            }, 
            '0x00',
            '0x000000000000000000000000' + ERC20.address.substring(2)
        ])
        await expect(eesee.connect(signer).buyTicketsWithSwap(currentListingID, swapData))
        .to.be.revertedWithCustomError(eesee, "InvalidSwapDescription")

        swapData = iface.encodeFunctionData('swap', [
            mock1InchExecutor.address, 
            {
                srcToken: ERC20.address,
                dstToken: ESE.address,
                srcReceiver: mock1InchExecutor.address,
                dstReceiver: eesee.address, 
                amount: 232,
                minReturnAmount: 100,
                flags: 0,
            }, 
            '0x00',
            '0x000000000000000000000000' + ERC20.address.substring(2)
        ])
        await expect(eesee.connect(signer).buyTicketsWithSwap(currentListingID, swapData, {value: 1}))//
        .to.be.revertedWithCustomError(eesee, "InvalidMsgValue")

        swapData = iface.encodeFunctionData('swap', [
            mock1InchExecutor.address, 
            {
                srcToken: ERC20.address,
                dstToken: ESE.address,
                srcReceiver: mock1InchExecutor.address,
                dstReceiver: eesee.address, 
                amount: 232, //should buy 2 tickets + 10 ESE dust + (10-1) ERC20 dust 
                minReturnAmount: 100,
                flags: 0,
            }, 
            '0x00',
            '0x000000000000000000000000' + ERC20.address.substring(2)
        ])

        const balanceBefore = await ESE.balanceOf(signer.address)
        const balanceBefore_ = await ERC20.balanceOf(signer.address)

        await expect(eesee.connect(signer).buyTicketsWithSwap(currentListingID, swapData))
            .to.emit(eesee, "BuyTicket").withArgs(currentListingID, signer.address, 0, 50)
            .to.emit(eesee, "BuyTicket").withArgs(currentListingID, signer.address, 1, 50)

        const balanceAfter = await ESE.balanceOf(signer.address)
        const balanceAfter_ = await ERC20.balanceOf(signer.address)

        assert.equal(balanceAfter.sub(balanceBefore).toString(), "10", 'ESE balance is correct')
        assert.equal(balanceBefore_.sub(balanceAfter_).toString(), "223", 'ERC20 balance is correct')

        swapData = iface.encodeFunctionData('swap', [
            mock1InchExecutor.address, 
            {
                srcToken: zeroAddress,
                dstToken: ESE.address,
                srcReceiver: mock1InchExecutor.address,
                dstReceiver: eesee.address, 
                amount: 212, //should buy 2 tickets + 10 ESE dust + (10-1) ERC20 dust 
                minReturnAmount: 100,
                flags: 0,
            }, 
            '0x00',
            '0x000000000000000000000000' + ERC20.address.substring(2)
        ])
        await expect(eesee.connect(signer).buyTicketsWithSwap(currentListingID, swapData, {value: 211}))//
        .to.be.revertedWithCustomError(eesee, "InvalidMsgValue")

        swapData = iface.encodeFunctionData('swap', [//TODO:check eth transfer
            mock1InchExecutor.address, 
            {
                srcToken: zeroAddress,
                dstToken: ESE.address,
                srcReceiver: mock1InchExecutor.address,
                dstReceiver: eesee.address, 
                amount: 64, //should buy 2 tickets + 8 ESE dust + (10-1) ETH dust
                minReturnAmount: 100,
                flags: 0,
            }, 
            '0x00',
            '0x000000000000000000000000' + ERC20.address.substring(2)
        ])

        const _balanceBefore = await ESE.balanceOf(acc9.address)
        const _balanceBefore_ = await ethers.provider.getBalance(acc9.address);

        const tx = await eesee.connect(acc9).buyTicketsWithSwap(currentListingID, swapData, {value: 64})
        const rr = await tx.wait()
        await expect(tx)
            .to.emit(eesee, "BuyTicket").withArgs(currentListingID, acc9.address, 2, 50)
            .to.emit(eesee, "BuyTicket").withArgs(currentListingID, acc9.address, 3, 50)

        const _balanceAfter = await ESE.balanceOf(acc9.address)
        const _balanceAfter_ = await ethers.provider.getBalance(acc9.address);

        assert.equal(_balanceAfter.sub(_balanceBefore).toString(), "8", 'ESE balance is correct')
        assert.equal(_balanceBefore_.sub(_balanceAfter_).sub(rr.gasUsed.mul(rr.effectiveGasPrice)).toString(), "55", 'ERC20 balance is correct')
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
        await expect(eesee.connect(signer).changeMaxTicketsBoughtByAddress('1000000000000000001')).to.be.revertedWithCustomError(eesee, "MaxTicketsBoughtByAddressTooHigh")
        await expect(eesee.connect(signer).changeMaxTicketsBoughtByAddress(newValue))
        .to.emit(eesee, "ChangeMaxTicketsBoughtByAddress")
        .withArgs(maxTicketsBoughtByAddress, newValue)
        assert.equal(newValue, await eesee.maxTicketsBoughtByAddress(), "maxTicketsBoughtByAddress has changed")

        const fee = await eesee.fee() 
        await expect(eesee.connect(acc2).changeFee(newValue)).to.be.revertedWith("Ownable: caller is not the owner")
        await expect(eesee.connect(signer).changeFee('500000000000000001')).to.be.revertedWithCustomError(eesee, "FeeTooHigh")
        await expect(eesee.connect(signer).changeFee(newValue))
        .to.emit(eesee, "ChangeFee")
        .withArgs(fee, newValue)
        assert.equal(newValue, await eesee.fee(), "fee has changed")

        newValue = zeroAddress
        const _feeCollector = await eesee.feeCollector() 
        await expect(eesee.connect(acc2).changeFeeCollector(newValue)).to.be.revertedWith("Ownable: caller is not the owner")
        await expect(eesee.connect(signer).changeFeeCollector(newValue))
        .to.emit(eesee, "ChangeFeeCollector")
        .withArgs(_feeCollector, newValue)
        assert.equal(newValue, await eesee.feeCollector(), "feeCollector has changed")
    })

    const getProof = (tree, address) => {
        let proof = null
        for (const [i, v] of tree.entries()) {
            if (v[0] === address) {
                proof = tree.getProof(i);
              }
        }
        return proof
    }
    
    it('drops', async () => {
        await eesee.connect(signer).changeFee('100000000000000000')
        await expect(eesee.connect(signer).changeFeeCollector(feeCollector.address))
        const eeseeNFTDrop = await hre.ethers.getContractFactory("eeseeNFTDrop")
        const leaves = []
        leaves.push([acc2.address])
        leaves.push([acc3.address])
        leaves.push([acc8.address])
        merkleTree = StandardMerkleTree.of(leaves, ['address'])
        const publicStage = {
            name: 'Public Stage',
            mintFee: ethers.utils.parseUnits('0.03', 'ether'),
            duration: 86400,
            perAddressMintLimit: 0,
            allowListMerkleRoot: '0x0000000000000000000000000000000000000000000000000000000000000000'
        }
        const presaleStages = [
            {
                name: 'Presale Stage 1',
                mintFee: 0,
                duration: 86400,
                perAddressMintLimit: 5,
                allowListMerkleRoot: merkleTree.root
            },
            {
                name: 'Presale Stage 2',
                mintFee: ethers.utils.parseUnits('0.02', 'ether'),
                duration: 86400,
                perAddressMintLimit: 5,
                allowListMerkleRoot: merkleTree.root
            }
        ]

        await expect(eesee.connect(acc8).listDrop(
            'apes',
            'bayc',
            'base/',
            'contract/',
            acc8.address,
            300,
            10,
            acc8.address,
            (await ethers.provider.getBlock()).timestamp + 86400,
            publicStage,
            presaleStages
        ))
        .to.emit(eesee, "ListDrop")
        .withArgs(1, anyValue, acc8.address)

        const ID = 1
        const listing = await eesee.drops(ID);
        assert.equal(listing.ID.toString(), ID.toString(), "ID is correct")
        assert.equal(listing.earningsCollector, acc8.address, "earningsCollector is correct")
        assert.equal(listing.fee.toString(), (await eesee.fee()).toString(), "Fee is correct")

        assert.equal(await eesee.getDropsLength(), 2, "Length is correct")

        await expect(eesee.connect(acc2).mintDrop(
            1, 2, getProof(merkleTree, acc2.address)
        )).to.be.revertedWithCustomError(eeseeNFTDrop, "MintingNotStarted")


        // Presale 1
        await time.increase(86401)

        let balanceBefore = await ESE.balanceOf(acc2.address)
        let collectorBalanceBefore = await ESE.balanceOf(acc8.address)
        let feeBalanceBefore = await ESE.balanceOf(feeCollector.address)
        await expect(eesee.connect(acc3).mintDrop(
            1, 2, getProof(merkleTree, acc3.address)
        )).to.emit(eesee, "MintDrop").withArgs(1, anyValue, acc3.address, 0)
        let balanceAfter = await ESE.balanceOf(acc2.address)
        let collectorBalanceAfter = await ESE.balanceOf(acc8.address)
        let feeBalanceAfter = await ESE.balanceOf(feeCollector.address)

        assert.equal(BigInt(balanceBefore) - BigInt(balanceAfter), 0, "Price paid is correct")
        assert.equal(BigInt(collectorBalanceBefore) - BigInt(collectorBalanceAfter), 0, "Amount collected is correct")
        assert.equal(BigInt(feeBalanceBefore) - BigInt(feeBalanceAfter), 0, "Fee is correct")

        const invalidMerkleTree = StandardMerkleTree.of([[acc4.address]], ['address'])
        await expect(eesee.connect(acc4).mintDrop(
            1, 2, getProof(invalidMerkleTree, acc4.address)
        )).to.be.revertedWithCustomError(eeseeNFTDrop, "NotInAllowlist")

        // Presale 2
        await time.increase(86401)
        let expectedFee = BigInt(ethers.utils.parseUnits('0.04', 'ether')) * BigInt(listing.fee) / BigInt('1000000000000000000')

        balanceBefore = await ESE.balanceOf(acc2.address)
        collectorBalanceBefore = await ESE.balanceOf(acc8.address)
        feeBalanceBefore = await ESE.balanceOf(feeCollector.address)
        await expect(eesee.connect(acc2).mintDrop(
            1, 2, getProof(merkleTree, acc2.address)
        ))
        .to.emit(eesee, "CollectFee").withArgs(feeCollector.address, expectedFee)
        .and.to.emit(eesee, "MintDrop").withArgs(1, anyValue, acc2.address, ethers.utils.parseUnits('0.02', 'ether'))
        .and.to.emit(eesee, "MintDrop").withArgs(1, anyValue, acc2.address, ethers.utils.parseUnits('0.02', 'ether'))

        balanceAfter = await ESE.balanceOf(acc2.address)
        collectorBalanceAfter = await ESE.balanceOf(acc8.address)
        feeBalanceAfter = await ESE.balanceOf(feeCollector.address)

        assert.equal(BigInt(balanceBefore) - BigInt(balanceAfter), ethers.utils.parseUnits('0.04', 'ether'), "Price paid is correct")
        assert.equal(BigInt(feeBalanceAfter) - BigInt(feeBalanceBefore), expectedFee, "Fee is correct")

        let expectedReceive = BigInt(ethers.utils.parseUnits('0.04', 'ether')) - expectedFee
        assert.equal(BigInt(collectorBalanceAfter) - BigInt(collectorBalanceBefore), expectedReceive, "Amount collected is correct")

        await expect(eesee.connect(acc4).mintDrop(
            1, 2, getProof(merkleTree, acc2.address)
        )).to.be.revertedWithCustomError(eeseeNFTDrop, "NotInAllowlist")

        // Presale 3
        await time.increase(86401)
        expectedFee = BigInt(ethers.utils.parseUnits('0.06', 'ether')) * BigInt(listing.fee) / BigInt('1000000000000000000')
        balanceBefore = await ESE.balanceOf(acc4.address)
        collectorBalanceBefore = await ESE.balanceOf(acc8.address)
        feeBalanceBefore = await ESE.balanceOf(feeCollector.address)
        await expect(eesee.connect(acc4).mintDrop(
            1, 2, getProof(invalidMerkleTree, acc4.address)
        ))
        .to.emit(eesee, "MintDrop").withArgs(1, anyValue, acc4.address, ethers.utils.parseUnits('0.03', 'ether'))
        .and.to.emit(eesee, "MintDrop").withArgs(1, anyValue, acc4.address, ethers.utils.parseUnits('0.03', 'ether'))
        .and.to.emit(eesee, "CollectFee").withArgs(feeCollector.address, expectedFee)
        
        balanceAfter = await ESE.balanceOf(acc4.address)
        collectorBalanceAfter = await ESE.balanceOf(acc8.address)
        feeBalanceAfter = await ESE.balanceOf(feeCollector.address)

        assert.equal(BigInt(balanceBefore) - BigInt(balanceAfter), ethers.utils.parseUnits('0.06', 'ether'), "Price paid is correct")
        assert.equal(BigInt(feeBalanceAfter) - BigInt(feeBalanceBefore), expectedFee, "Fee is correct")

        expectedReceive = BigInt(ethers.utils.parseUnits('0.06', 'ether')) - expectedFee
        assert.equal(BigInt(collectorBalanceAfter) - BigInt(collectorBalanceBefore), expectedReceive, "Amount collected is correct")
    })
});
