// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/Ieesee.sol";
import '@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol';
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract eesee is Ieesee, AxelarExecutable, ERC721Holder, Ownable {
    using SafeERC20 for IERC20;
    ///@dev An array of all existing listings.
    Listing[] public listings;
    ///@dev An array of all existing drops listings.
    Drop[] public drops;

    ///@dev ESE token this contract uses.
    IERC20 public immutable ESE;
    ///@dev Contract that mints NFTs
    IeeseeMinter public immutable minter;

    ///@dev Min and max durations for a listing.
    uint256 public minDuration = 1 days;
    uint256 public maxDuration = 30 days;
    ///@dev Max tickets bought by a single address in a single listing. [1 ether == 100%]
    //Note: Users can still buy 1 ticket even if this check fails. e.g. there is a listing with only 2 tickets and this is set to 20%.
    uint256 public maxTicketsBoughtByAddress = 0.20 ether;
    ///@dev Fee that is collected to {feeCollector} from each fulfilled listing. [1 ether == 100%]
    uint256 public fee = 0.10 ether;
    ///@dev Address {fee}s are sent to.
    address public feeCollector;

    ///@dev The Royalty Engine is a contract that provides an easy way for any marketplace to look up royalties for any given token contract.
    IRoyaltyEngineV1 immutable public royaltyEngine;

    ///@dev To save gas we call Chainlink on Polygon network using Axelar.
    IAxelarGasService public immutable gasService;
    ///@dev Chainlink caller contract's chain.
    string public destinationChain;
    ///@dev Chainlink caller contract's address.
    string public destinationAddress;
    bytes32 private immutable destinationHash;

    ///@dev ChainLink price feeds for MATIC/ETH calculation.
    AggregatorV3Interface public immutable priceFeed_MATIC_USD;
    AggregatorV3Interface public immutable priceFeed_ETH_USD;

    constructor(
        IERC20 _ESE,
        IeeseeMinter _minter,
        address _feeCollector,
        IRoyaltyEngineV1 _royaltyEngine,
        address _gateway, 
        IAxelarGasService _gasService,
        string memory _destinationChain, 
        string memory _destinationAddress,
        AggregatorV3Interface _priceFeed_MATIC_USD,
        AggregatorV3Interface _priceFeed_ETH_USD
    ) AxelarExecutable(_gateway) {
        ESE = _ESE;
        minter = _minter;
        feeCollector = _feeCollector;
        royaltyEngine = _royaltyEngine;

        gasService = _gasService;
        destinationChain = _destinationChain;
        destinationAddress = _destinationAddress;
        destinationHash = keccak256(abi.encodePacked(destinationChain, destinationAddress));

        priceFeed_MATIC_USD = _priceFeed_MATIC_USD;
        priceFeed_ETH_USD = _priceFeed_ETH_USD;

        //Create dummy listings at index 0
        listings.push();
        drops.push();
    }

    // ============ External Methods ============

    /**
     * @dev Lists NFT from sender's balance. Emits {ListItem} event.
     * @param nft - NFT to list. Note: The sender must have it approved for this contract.
     * @param maxTickets - Max amount of tickets that can be bought by participants.
     * @param ticketPrice - Price for a single ticket.
     * @param duration - Duration of listings. Can be in range [minDuration, maxDuration].
     
     * @return ID - ID of listing created.
     */
    function listItem(NFT memory nft, uint256 maxTickets, uint256 ticketPrice, uint256 duration) external returns(uint256 ID){
        nft.collection.safeTransferFrom(msg.sender, address(this), nft.tokenID);
        ID = _listItem(nft, maxTickets, ticketPrice, duration);
    }

    /**
     * @dev Lists NFTs from sender's balance. Emits {ListItem} events for each NFT listed.
     * @param nfts - NFTs to list. Note: The sender must have them approved for this contract.
     * @param maxTickets - Max amount of tickets that can be bought by participants.
     * @param ticketPrices - Prices for a single ticket.
     * @param durations - Durations of listings. Can be in range [minDuration, maxDuration].
     
     * @return IDs - IDs of listings created.
     */
    function listItems(
        NFT[] memory nfts, 
        uint256[] memory maxTickets, 
        uint256[] memory ticketPrices, 
        uint256[] memory durations
    ) external returns(uint256[] memory IDs){
        require(
            nfts.length == maxTickets.length && maxTickets.length == ticketPrices.length && ticketPrices.length == durations.length, 
            "eesee: Arrays don't match lengths"
        );
        IDs = new uint256[](nfts.length);
        for(uint256 i = 0; i < nfts.length; i++) {
            nfts[i].collection.safeTransferFrom(msg.sender, address(this), nfts[i].tokenID);
            IDs[i] = _listItem(nfts[i], maxTickets[i], ticketPrices[i], durations[i]);
        }
    }

    /**
     * @dev Mints NFT to a public collection and lists it. Emits {ListItem} event.
     * @param tokenURI - Token metadata URI.
     * @param maxTickets - Max amounts of tickets that can be bought by participants.
     * @param ticketPrice - Price for a single ticket.
     * @param duration - Duration of listing. Can be in range [minDuration, maxDuration].
     * @param royaltyReceiver - Receiver of royalties from each NFT sale.
     * @param royaltyFeeNumerator - Amount of royalties to collect from each NFT sale. [10000 = 100%].

     * @return ID - ID of listing created.
     * @return collection - Address of NFT collection contract.
     * @return tokenID - ID of token that was minted.
     * Note This function costs less than mintAndListItemWithDeploy() but does not deploy additional NFT collection contract
     */
    function mintAndListItem(
        string memory tokenURI, 
        uint256 maxTickets, 
        uint256 ticketPrice, 
        uint256 duration,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external returns(uint256 ID, IERC721 collection, uint256 tokenID){
        string[] memory tokenURIs = new string[](1);
        tokenURIs[0] = tokenURI;
        
        uint256[] memory tokenIDs;
        (collection, tokenIDs) = minter.mintToPublicCollection(1, tokenURIs, royaltyReceiver, royaltyFeeNumerator);
        tokenID = tokenIDs[0];
        ID = _listItem(NFT(collection, tokenID), maxTickets, ticketPrice, duration);
    }

    /**
     * @dev Mints NFTs to a public collection and lists them. Emits {ListItem} event for each NFT listed.
     * @param tokenURIs - Token metadata URIs.
     * @param maxTickets - Max amounts of tickets that can be bought by participants.
     * @param ticketPrices - Prices for a single ticket.
     * @param durations - Durations of listings. Can be in range [minDuration, maxDuration].
     * @param royaltyReceiver - Receiver of royalties from each NFT sale.
     * @param royaltyFeeNumerator - Amount of royalties to collect from each NFT sale. [10000 = 100%].
     
     * @return IDs - IDs of listings created.
     * @return collection - Address of NFT collection contract.
     * @return tokenIDs - IDs of tokens that were minted.
     * Note This function costs less than mintAndListItemsWithDeploy() but does not deploy additional NFT collection contract
     */
    function mintAndListItems(
        string[] memory tokenURIs, 
        uint256[] memory maxTickets, 
        uint256[] memory ticketPrices, 
        uint256[] memory durations,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external returns(uint256[] memory IDs, IERC721 collection, uint256[] memory tokenIDs){
        require(maxTickets.length == ticketPrices.length && maxTickets.length == durations.length, "eesee: Arrays don't match lengths");
        (collection, tokenIDs) = minter.mintToPublicCollection(maxTickets.length, tokenURIs, royaltyReceiver, royaltyFeeNumerator);

        IDs = new uint256[](maxTickets.length);
        for(uint256 i; i < maxTickets.length; i++){
            IDs[i] = _listItem(NFT(collection, tokenIDs[i]), maxTickets[i], ticketPrices[i], durations[i]);
        }
    }

    /**
     * @dev Deploys new NFT collection contract, mints NFT to it and lists it. Emits {ListItem} event.
     * @param name - Name for a collection.
     * @param symbol - Collection symbol.
     * @param baseURI - URI to store NFT metadata in.
     * @param maxTickets - Max amounts of tickets that can be bought by participants.
     * @param ticketPrice - Price for a single ticket.
     * @param duration - Duration of listing. Can be in range [minDuration, maxDuration].
     * @param royaltyReceiver - Receiver of royalties from each NFT sale.
     * @param royaltyFeeNumerator - Amount of royalties to collect from each NFT sale. [10000 = 100%].
     
     * @return ID - ID of listings created.
     * @return collection - Address of NFT collection contract.
     * @return tokenID - ID of tokens that were minted.
     * Note: This is more expensive than mintAndListItem() function but it deploys additional NFT contract.
     */
    function mintAndListItemWithDeploy(
        string memory name, 
        string memory symbol, 
        string memory baseURI, 
        string memory contractURI,
        uint256 maxTickets, 
        uint256 ticketPrice,
        uint256 duration,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external returns(uint256 ID, IERC721 collection, uint256 tokenID){
        uint256[] memory tokenIDs;
        (collection, tokenIDs) = minter.mintToPrivateCollection(1, name, symbol, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator);
        tokenID = tokenIDs[0];
        ID = _listItem(NFT(collection, tokenID), maxTickets, ticketPrice, duration);
    }

    /**
     * @dev Deploys new NFT collection contract, mints NFTs to it and lists them. Emits {ListItem} event for each NFT listed.
     * @param name - Name for a collection.
     * @param symbol - Collection symbol.
     * @param baseURI - URI to store NFT metadata in.
     * @param maxTickets - Max amounts of tickets that can be bought by participants.
     * @param ticketPrices - Prices for a single ticket.
     * @param durations - Durations of listings. Can be in range [minDuration, maxDuration].
     * @param royaltyReceiver - Receiver of royalties from each NFT sale.
     * @param royaltyFeeNumerator - Amount of royalties to collect from each NFT sale. [10000 = 100%].
     
     * @return IDs - IDs of listings created.
     * @return collection - Address of NFT collection contract.
     * @return tokenIDs - IDs of tokens that were minted.
     * Note: This is more expensive than mintAndListItems() function but it deploys additional NFT contract.
     */
    function mintAndListItemsWithDeploy(
        string memory name, 
        string memory symbol, 
        string memory baseURI, 
        string memory contractURI,
        uint256[] memory maxTickets, 
        uint256[] memory ticketPrices,
        uint256[] memory durations,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external returns(uint256[] memory IDs, IERC721 collection, uint256[] memory tokenIDs){
        require(maxTickets.length == ticketPrices.length && maxTickets.length == durations.length, "eesee: Arrays don't match lengths");
        (collection, tokenIDs) = minter.mintToPrivateCollection(maxTickets.length, name, symbol, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator);
        
        IDs = new uint256[](maxTickets.length);
        for(uint256 i; i < maxTickets.length; i++){
            IDs[i] = _listItem(NFT(collection, tokenIDs[i]), maxTickets[i], ticketPrices[i], durations[i]);
        }
    }

    /**
     * @dev Buys tickets to participate in a draw. Requests Axelar to send request to {destinationAddress} to generate random words if all tickets have been bought. Emits {BuyTicket} event for each ticket bought.
     * @param ID - ID of a listing to buy tickets for.
     * @param amount - Amount of tickets to buy. A single address can't buy more than {maxTicketsBoughtByAddress} of all tickets. 
     
     * @return tokensSpent - ESE tokens spent.
     */
    function buyTickets(uint256 ID, uint256 amount) external returns(uint256 tokensSpent){
        require(amount > 0, "eesee: Amount must be above zero");
        Listing storage listing = listings[ID];
        require(listing.owner != address(0), "eesee: Listing does not exist");
        require(block.timestamp <= listing.creationTime + listing.duration, "eesee: Listing has already expired");

        tokensSpent = listing.ticketPrice * amount;
        ESE.safeTransferFrom(msg.sender, address(this), tokensSpent);

        for(uint256 i; i < amount; i++){
            emit BuyTicket(ID, msg.sender, listing.ticketsBought, listing.ticketPrice);
            listing.ticketIDBuyer[listing.ticketsBought] = msg.sender;
            listing.ticketsBought += 1;
        }
        listing.ticketsBoughtByAddress[msg.sender] += amount;

        //Allow buy single tickets even if bought amount is more than maxTicketsBoughtByAddress
        if(listing.ticketsBoughtByAddress[msg.sender] > 1){
            require(listing.ticketsBoughtByAddress[msg.sender] * 1 ether / listing.maxTickets <= maxTicketsBoughtByAddress, "eesee: Max tickets bought by this address");
        }
        require(listing.ticketsBought <= listing.maxTickets, "eesee: All tickets bought");

        if(listing.ticketsBought == listing.maxTickets){
            (,int256 MATIC_USD,,,) = priceFeed_MATIC_USD.latestRoundData();
            (,int256 ETH_USD,,,) = priceFeed_ETH_USD.latestRoundData();
            require((MATIC_USD > 0) && (ETH_USD > 0), "eesee: Unstable pricing");

            bytes memory payload = abi.encode(ID, listing.maxTickets);
            uint256 denominator_MATIC_USD = 10^priceFeed_MATIC_USD.decimals();
            uint256 denominator_ETH_USD = 10^priceFeed_ETH_USD.decimals();
            // uint256 MATIC_ETH = (MATIC_USD / denominator_MATIC_USD) / (ETH_USD / denominator_ETH_USD);
            //Note: This contract must have [40000 gas limit * 500 gwei] Matic. We multiply by {MATIC_ETH} to get amount in ETH.
            gasService.payNativeGasForContractCall{
                value: 40000 * 500 gwei * uint256(MATIC_USD) * denominator_ETH_USD / denominator_MATIC_USD / uint256(ETH_USD)
            }(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                address(this)
            );
            gateway.callContract(destinationChain, destinationAddress, payload);
            emit RequestWords(ID);
        }
    }

    /**
     * @dev Deploys new NFT collection and lists it to users for minting. Emits {ListDrop} event.
     * @param name - Name for a collection.
     * @param symbol - Collection symbol.
     * @param URI - URI to store NFT metadata in.
     * @param contractURI - URI to store collection metadata in.
     * @param royaltyReceiver - Receiver of royalties from each NFT sale.
     * @param royaltyFeeNumerator - Amount of royalties to collect from each NFT sale. [10000 = 100%].
     * @param mintLimit - Max amount of NFTs that can be minted.
     * @param earningsCollector - Address to send NFT sale earnings to.
     * @param mintStartTimestamp - Timestamp when minting starts.
     * @param publicStageOptions - Option for public stage.
     * @param presalesOptions - Options for presales stages.

     * @return ID - ID of a drop created.
     * @return collection - Address of NFT collection contract.
     */
    function listDrop(
        string memory name,
        string memory symbol,
        string memory URI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        uint256 mintLimit,
        address earningsCollector,
        uint256 mintStartTimestamp, 
        IeeseeNFTDrop.StageOptions memory publicStageOptions,
        IeeseeNFTDrop.StageOptions[] memory presalesOptions
    ) external returns (uint256 ID, IERC721 collection){
        require(earningsCollector != address(0), "eesee: Invalid earningsCollector");
        collection = minter.deployDropCollection(
            name,
            symbol,
            URI,
            contractURI,
            royaltyReceiver,
            royaltyFeeNumerator,
            mintLimit,
            mintStartTimestamp,
            publicStageOptions,
            presalesOptions
        );

        ID = drops.length;
        Drop storage drop = drops.push();
        drop.ID = ID;
        drop.collection = collection;
        drop.earningsCollector = earningsCollector;
        drop.fee = fee;

        emit ListDrop(ID, collection, earningsCollector);
    }

    /**
     * @dev Mints NFTs from a drop. Emits {MintDrop} event.
     * @param ID - ID of a drop to mint NFTs from.
     * @param quantity - Amount of NFTs to mint.
     * @param merkleProof - Merkle proof for a user to mint NFTs.

     * @return mintPrice - Amount of ESE tokens spent on minting.
     */
    function mintDrop(uint256 ID, uint256 quantity, bytes32[] memory merkleProof) external returns(uint256 mintPrice){
        require(quantity > 0, "eesee: Quantity must be above zero");
        Drop storage drop = drops[ID];

        IeeseeNFTDrop _drop = IeeseeNFTDrop(address(drop.collection));
        uint256 nextTokenId = _drop.nextTokenId();
        _drop.mint(msg.sender, quantity, merkleProof);

        (,,IeeseeNFTDrop.StageOptions memory stageOptions) = _drop.stages(_drop.getSaleStage()); 
        uint256 mintFee = stageOptions.mintFee;
        if (mintFee != 0) {
            mintPrice = mintFee * quantity;
            ESE.safeTransferFrom(msg.sender, address(this), mintPrice);
            uint256 fees = _collectFee(mintPrice, drop.fee);
            ESE.safeTransfer(drop.earningsCollector, mintPrice - fees);
        }

        for(uint256 i; i < quantity; i++){
            emit MintDrop(ID, NFT(drop.collection, nextTokenId + i), msg.sender, mintFee);
        }
    }

    /**
     * @dev Receive NFTs the sender won from listings. Emits {ReceiveItem} event for each of the NFT received.
     * @param IDs - IDs of listings to claim NFTs in.
     * @param recipient - Address to send NFTs to. 
     
     * @return collections - Addresses of tokens received.
     * @return tokenIDs - IDs of tokens received.
     * Note: Returning an array of NFT structs gives me "Stack too deep" error for some reason, so I have to return it this way
     */
    function batchReceiveItems(uint256[] memory IDs, address recipient) external returns(IERC721[] memory collections, uint256[] memory tokenIDs){
        require(recipient != address(0), "eesee: Invalid recipient");
        collections = new IERC721[](IDs.length);
        tokenIDs = new uint256[](IDs.length);

        for(uint256 i; i < IDs.length; i++){
            uint256 ID = IDs[i];
            Listing storage listing = listings[ID];
            require(listing.winner == msg.sender, "eesee: Caller is not the winner");
            require(!listing.itemClaimed, "eesee: Item has already been claimed");

            collections[i] = listing.nft.collection;
            tokenIDs[i] = listing.nft.tokenID;
            listing.itemClaimed = true;
            listing.nft.collection.safeTransferFrom(address(this), recipient, listing.nft.tokenID);

            emit ReceiveItem(ID, listing.nft, recipient);

            if(listing.tokensClaimed){
                delete listings[ID];
            }
        }
    }

    /**
     * @dev Receive ESE the sender has earned from listings. Emits {ReceiveTokens} event for each of the claimed listing.
     * @param IDs - IDs of listings to claim tokens in.
     * @param recipient - Address to send tokens to.
     
     * @return amount - ESE received.
     */
    function batchReceiveTokens(uint256[] memory IDs, address recipient) external returns(uint256 amount){
        require(recipient != address(0), "eesee: Invalid recipient");
        for(uint256 i; i < IDs.length; i++){
            uint256 ID = IDs[i];
            Listing storage listing = listings[ID];
            require(listing.winner != address(0), "eesee: Listing is not filfilled");
            require(listing.owner == msg.sender, "eesee: Caller is not the owner");
            require(!listing.tokensClaimed, "eesee: Tokens have already been claimed");

            listing.tokensClaimed = true;
            uint256 _amount = listing.ticketPrice * listing.maxTickets;
            _amount -= _collectRoyalties(_amount, listing.nft, listing.owner);
            _amount -= _collectFee(_amount, listing.fee);
            amount += _amount;

            emit ReceiveTokens(ID, recipient, _amount);

            if(listing.itemClaimed){
                delete listings[ID];
            }
        }
        // Transfer later to save gas
        ESE.safeTransfer(recipient, amount);
    }

    /**
     * @dev Reclaim NFTs from expired listings. Emits {ReclaimItem} event for each listing ID.
     * @param IDs - IDs of listings to reclaim NFTs in.
     * @param recipient - Address to send NFTs to.
     
     * @return collections - Addresses of tokens reclaimed.
     * @return tokenIDs - IDs of tokens reclaimed.
     * Note: returning an array of NFT structs gives me "Stack too deep" error for some reason, so I have to return it this way
     */
    function batchReclaimItems(uint256[] memory IDs, address recipient) external returns(IERC721[] memory collections, uint256[] memory tokenIDs){
        require(recipient != address(0), "eesee: Invalid recipient");
        collections = new IERC721[](IDs.length);
        tokenIDs = new uint256[](IDs.length);

        for(uint256 i; i < IDs.length; i++){
            uint256 ID = IDs[i];
            Listing storage listing = listings[ID];
            require(msg.sender == listing.owner, "eesee: Caller is not the owner");
            require(block.timestamp > listing.creationTime + listing.duration, "eesee: Listing has not expired yet");
            require(!listing.itemClaimed, "eesee: Item has already been claimed");
            require(listing.winner == address(0), "eesee: Listing is already filfilled");

            collections[i] = listing.nft.collection;
            tokenIDs[i] = listing.nft.tokenID;
            listing.itemClaimed = true;
            listing.nft.collection.safeTransferFrom(address(this), recipient, listing.nft.tokenID);

            emit ReclaimItem(ID, listing.nft, recipient);

            if(listing.ticketsBought == 0){
                delete listings[ID];
            }
        }
    }

    /**
     * @dev Reclaim ESE from expired listings. Emits {ReclaimTokens} event for each listing ID.
     * @param IDs - IDs of listings to reclaim tokens in.
     * @param recipient - Address to send tokens to.
     
     * @return amount - ESE received.
     */
    function batchReclaimTokens(uint256[] memory IDs, address recipient) external returns(uint256 amount){
        require(recipient != address(0), "eesee: Invalid recipient");
        for(uint256 i; i < IDs.length; i++){
            uint256 ID = IDs[i];
            Listing storage listing = listings[ID];
            uint256 ticketsBoughtByAddress = listing.ticketsBoughtByAddress[msg.sender];
            require(ticketsBoughtByAddress > 0, "eesee: No tickets bought");
            require(block.timestamp > listing.creationTime + listing.duration, "eesee: Listing has not expired yet");
            require(listing.winner == address(0), "eesee: Listing is already filfilled");

            listing.ticketsBought -= ticketsBoughtByAddress;
            listing.ticketsBoughtByAddress[msg.sender] = 0;

            uint256 _amount = ticketsBoughtByAddress * listing.ticketPrice;
            amount += _amount;

            emit ReclaimTokens(ID, msg.sender, recipient, ticketsBoughtByAddress, _amount);

            if(listing.ticketsBought == 0 && listing.itemClaimed){
                delete listings[ID];
            }
        }
        // Transfer later to save some gas
        ESE.safeTransfer(recipient, amount);
    }

    // ============ Getters ============

    /**
     * @dev Get length of the listings array.
     * @return length - Length of the listings array.
     */
    function getListingsLength() external view returns(uint256 length) {
        length = listings.length;
    }

    /**
     * @dev Get length of the drops array.
     * @return length - Length of the drops array.
     */
    function getDropsLength() external view returns(uint256 length) {
        length = drops.length;
    }

    /**
     * @dev Get the buyer of the specified ticket in listing.
     * @param ID - ID of the listing.
     * @param ticket - Ticket index.
     
     * @return address - Ticket buyer.
     */
    function getListingTicketIDBuyer(uint256 ID, uint256 ticket) external view returns(address) {
        return listings[ID].ticketIDBuyer[ticket];
    }
    
    /**
     * @dev Get the amount of tickets bought by address in listing.
     * @param ID - ID of the listing.
     * @param _address - Buyer address.
     
     * @return uint256 - Tickets bought by {_address}.
     */
    function getListingTicketsBoughtByAddress(uint256 ID, address _address) external view returns(uint256) {
        return listings[ID].ticketsBoughtByAddress[_address];
    }

    // ============ Internal Methods ============

    // Note: Must be called after nft was minted/transfered
    function _listItem(NFT memory nft, uint256 maxTickets, uint256 ticketPrice, uint256 duration) internal returns(uint256 ID){
        require(duration >= minDuration, "eesee: Duration must be more or equal minDuration");
        require(duration <= maxDuration, "eesee: Duration must be less or equal maxDuration");
        require(maxTickets >= 2, "eesee: Max tickets must be more or equal 2");
        require(ticketPrice > 0, "eesee: Ticket price must be above zero");

        ID = listings.length;

        Listing storage listing = listings.push();
        listing.ID = ID;
        listing.nft = nft;
        listing.owner = msg.sender;
        listing.maxTickets = maxTickets;
        listing.ticketPrice = ticketPrice;
        listing.fee = fee; // We save fees at the time of listing's creation to not have any control over existing listings' fees
        listing.creationTime = block.timestamp;
        listing.duration = duration;

        emit ListItem(ID, nft, listing.owner, maxTickets, ticketPrice, duration);
    }

    function _collectRoyalties(uint256 value, NFT memory nft, address listingOwner) internal returns(uint256 royaltyAmount) {
        (address payable[] memory recipients, uint256[] memory amounts) = royaltyEngine.getRoyalty(address(nft.collection), nft.tokenID, value);
        for(uint256 i = 0; i < recipients.length; i++){
            //There is no reason to collect royalty from owner if it goes to owner
            if (recipients[i] != address(0) && recipients[i] != listingOwner && amounts[i] != 0){
                ESE.safeTransfer(recipients[i], amounts[i]);
                royaltyAmount += amounts[i];
                emit CollectRoyalty(recipients[i], amounts[i]);
            }
        }
    }

    function _collectFee(uint256 amount, uint256 _fee) internal returns(uint256 feeAmount){
        if(feeCollector == address(0)){
            return 0;
        }
        feeAmount = amount * _fee / 1 ether;
        if(feeAmount > 0){
            ESE.safeTransfer(feeCollector, feeAmount);
            emit CollectFee(feeCollector, feeAmount);
        }
    }

    /**
     * @dev This function is called by Axelar. Chooses listing winner and emits {FulfillListing} event.
     * @param sourceChain - The chain this function was called from.
     * @param sourceAddress - The address this function was called from.
     * @param payload - {ID, chosenTicket} abi encoded.
     */
    //TODO: get execute gasLimit for better approximation
     function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) internal override {
        require(keccak256(abi.encodePacked(sourceChain, sourceAddress)) == destinationHash, "eesee: Incorrect caller");
        
        (uint256 ID, uint256 chosenTicket) = abi.decode(payload, (uint256, uint256));
        Listing storage listing = listings[ID];
        require(block.timestamp <= listing.creationTime + listing.duration, "eesee: Listing has already expired");

        listing.winner = listing.ticketIDBuyer[chosenTicket];
        emit FulfillListing(ID, listing.nft, listing.winner);
    }

    // ============ Admin Methods ============

    /**
     * @dev Changes minDuration. Emits {ChangeMinDuration} event.
     * @param _minDuration - New minDuration.
     * Note: This function can only be called by owner.
     */
    function changeMinDuration(uint256 _minDuration) external onlyOwner {
        emit ChangeMinDuration(minDuration, _minDuration);
        minDuration = _minDuration;
    }

    /**
     * @dev Changes maxDuration. Emits {ChangeMaxDuration} event.
     * @param _maxDuration - New maxDuration.
     * Note: This function can only be called by owner.
     */
    function changeMaxDuration(uint256 _maxDuration) external onlyOwner {
        emit ChangeMaxDuration(maxDuration, _maxDuration);
        maxDuration = _maxDuration;
    }

    /**
     * @dev Changes maxTicketsBoughtByAddress. Emits {ChangeMaxTicketsBoughtByAddress} event.
     * @param _maxTicketsBoughtByAddress - New maxTicketsBoughtByAddress.
     * Note: This function can only be called by owner.
     */
    function changeMaxTicketsBoughtByAddress(uint256 _maxTicketsBoughtByAddress) external onlyOwner {
        require(_maxTicketsBoughtByAddress <= 1 ether, "eesee: Can't set maxTicketsBoughtByAddress to more than 100%");

        emit ChangeMaxTicketsBoughtByAddress(maxTicketsBoughtByAddress, _maxTicketsBoughtByAddress);
        maxTicketsBoughtByAddress = _maxTicketsBoughtByAddress;
    }

    /**
     * @dev Changes fee. Emits {ChangeFee} event.
     * @param _fee - New fee.
     * Note: This function can only be called by owner.
     */
    function changeFee(uint256 _fee) external onlyOwner {
        require(_fee <= 0.4 ether, "eesee: Can't set fees to more than 40%");

        emit ChangeFee(fee, _fee);
        fee = _fee;
    }

    /**
     * @dev Changes feeCollector. Emits {ChangeFeeCollector} event.
     * @param _feeCollector - New feeCollector.
     * Note: This function can only be called by owner.
     */
    function changeFeeCollector(address _feeCollector) external onlyOwner{
        emit ChangeFeeCollector(feeCollector, _feeCollector);
        feeCollector = _feeCollector;
    }

    ///@dev To call payNativeGasForContractCall this contract must have ETH in it.
    receive() external payable {}
}