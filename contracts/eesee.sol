// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./eeseePool.sol";
import "./IEesee.sol";

//TODO: recheck everything + tests
contract eesee is IEesee, VRFConsumerBaseV2, ERC721Holder, Ownable {
    using SafeERC20 for IERC20;

    ///@dev An array of all existing listings.
    Listing[] public listings;
    ///@dev Maps chainlink request ID to listing ID.
    mapping(uint256 => uint256) private chainlinkRequestIDs;

    ///@dev ESE token this contract uses.
    IERC20 public immutable ESE;
    ///@dev Reward pool the fees are sent to.
    address public immutable rewardPool;
    ///@dev Reward pool {poolFee} fees are sent to.
    eeseeNFT public immutable publicMinter;

    ///@dev Min and max durations for a listing.
    uint256 public minDuration = 1 days;
    uint256 public maxDuration = 30 days;
    ///@dev Max tickets bought by a single address in a single listing. [1 ether == 100%]
    //Note: Users can still buy 1 ticket even if this check fails. e.g. there is a listing with only 2 tickets and this is set to 20%.
    uint256 public maxTicketsBoughtByAddress = 0.20 ether;
    ///@dev Fixed fee that is collected if NFT is minted using this contract.
    uint256 public mintFee = 10 ether;
    ///@dev Fee that is collected to {feeCollector} from each fulfilled listing. [1 ether == 100%]
    uint256 public devFee = 0.02 ether;
    ///@dev Fee that is collected to {rewardPool} from each fulfilled listing. [1 ether == 100%]
    uint256 public poolFee = 0.08 ether;
    ///@dev Address {devFee} fees are sent to.
    address public feeCollector;

    ///@dev Chainlink token.
    LinkTokenInterface immutable public LINK;
    ///@dev Chainlink VRF V2 coordinator.
    VRFCoordinatorV2Interface immutable public vrfCoordinator;
    ///@dev Chainlink VRF V2 subscription ID.
    uint64 immutable public subscriptionID;
    ///@dev Chainlink VRF V2 key hash to call requestRandomWords() with.
    bytes32 immutable public keyHash;
    ///@dev Chainlink VRF V2 request confirmations.
    uint16 immutable public minimumRequestConfirmations;
    ///@dev Chainlink VRF V2 gas limit to call fulfillRandomWords().
    uint32 immutable private callbackGasLimit;

    constructor(
        IERC20 _ESE,
        address _rewardPool,
        string memory baseURI,
        address _feeCollector,
        address _vrfCoordinator, 
        LinkTokenInterface _LINK,
        bytes32 _keyHash,
        uint16 _minimumRequestConfirmations,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        ESE = _ESE;
        rewardPool = _rewardPool;
        // Deploy NFT contract for mintAndListItems() function that mints NFTs to existing collection
        publicMinter = new eeseeNFT("ESE Public Collection", "ESE-Public", baseURI);

        feeCollector = _feeCollector;

        // ChainLink stuff. Create subscription for VRF V2.
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionID = vrfCoordinator.createSubscription();
        vrfCoordinator.addConsumer(subscriptionID, address(this));
        LINK = _LINK;
        keyHash = _keyHash;
        minimumRequestConfirmations = _minimumRequestConfirmations;
        callbackGasLimit = _callbackGasLimit;

        //Create dummy listing at index 0
        listings.push();
    }

    // ============ External Methods ============

    function batchListItems(Item[] memory items) external returns(uint256[] memory){
        uint256[] memory IDs = new uint256[](items.length);
        for(uint256 i = 0; i < items.length; i++) {
            items[i].nft.token.safeTransferFrom(msg.sender, address(this), items[i].nft.tokenID);
            IDs[i] = _listItem(items[i].nft, items[i].maxTickets, items[i].ticketPrice, items[i].duration);
        }
        return IDs;
    }
    /**
     * @dev Lists NFT from sender's balance. Emits {ListItem} event.
     * @param nft - NFT to list. Note: The sender must have it approved for this contract.
     * @param maxTickets - Max amount of tickets that can be bought by participants.
     * @param ticketPrice - Price for a single ticket.
     * @param duration - Duration of listings. Can be in range [minDuration, maxDuration].
     
     * @return ID - ID of listing created.
     */
    function listItem(NFT memory nft, uint256 maxTickets, uint256 ticketPrice, uint256 duration) external returns(uint256 ID){
        nft.token.safeTransferFrom(msg.sender, address(this), nft.tokenID);
        ID = _listItem(nft, maxTickets, ticketPrice, duration);
    }

    /**
     * @dev Mints NFTs to {publicMinter} collection and lists them. Emits {ListItem} event for each NFT listed.
     * @param maxTickets - Max amounts of tickets that can be bought by participants.
     * @param ticketPrices - Prices for a single ticket.
     * @param durations - Durations of listings. Can be in range [minDuration, maxDuration].
     
     * @return IDs - IDs of listings created.
     * @return tokenIDs - IDs of tokens that were minted.
     * Note This function costs less than mintAndListItemsWithDeploy() but does not deploy additional NFT collection contract
     * Note The sender must have {mintFee} of ESE approved.
     */
    function mintAndListItems(
        uint256[] memory maxTickets, 
        uint256[] memory ticketPrices, 
        uint256[] memory durations
    ) external returns(uint256[] memory IDs, uint256[] memory tokenIDs){
        require(maxTickets.length == ticketPrices.length && maxTickets.length == durations.length, "eesee: Arrays don't match lengths");
        _collectMintFee();
        uint256 startTokenId = publicMinter.nextTokenId();
        publicMinter.mint(maxTickets.length);

        IDs = new uint256[](maxTickets.length);
        tokenIDs = new uint256[](maxTickets.length);
        for(uint256 i; i < maxTickets.length; i++){
            tokenIDs[i] = i + startTokenId;
            IDs[i] = _listItem(NFT(IERC721(address(publicMinter)), tokenIDs[i]), maxTickets[i], ticketPrices[i], durations[i]);
        }
    }

    /**
     * @dev Deploys new NFT collection contract, mints NFTs to it and lists them. Emits {ListItem} event for each NFT listed.
     * @param name - Name for a collection.
     * @param symbol - Collection symbol.
     * @param baseURI - URI to store NFT metadata in.
     * @param maxTickets - Max amounts of tickets that can be bought by participants.
     * @param ticketPrices - Prices for a single ticket.
     * @param durations - Durations of listings. Can be in range [minDuration, maxDuration].
     
     * @return IDs - IDs of listings created.
     * @return tokenIDs - IDs of tokens that were minted.
     * Note: This is more expensive than mintAndListItems() function but it deploys additional NFT contract.
     * Note The sender must have {mintFee} of ESE approved.
     */
    function mintAndListItemsWithDeploy(
        string memory name, 
        string memory symbol, 
        string memory baseURI, 
        uint256[] memory maxTickets, 
        uint256[] memory ticketPrices,
        uint256[] memory durations
    ) external returns(uint256[] memory IDs, uint256[] memory tokenIDs){
        require(maxTickets.length == ticketPrices.length && maxTickets.length == durations.length, "eesee: Arrays don't match lengths");
        _collectMintFee();
        eeseeNFT NFTMinter = new eeseeNFT(name, symbol, baseURI);
        NFTMinter.mint(maxTickets.length);
        NFTMinter.renounceOwnership();

        uint256 startTokenId = NFTMinter.startTokenId();
        IDs = new uint256[](maxTickets.length);
        tokenIDs = new uint256[](maxTickets.length);
        for(uint256 i; i < maxTickets.length; i++){
            tokenIDs[i] = i + startTokenId;
            IDs[i] = _listItem(NFT(IERC721(address(NFTMinter)), tokenIDs[i]), maxTickets[i], ticketPrices[i], durations[i]);
        }
    }

    /**
     * @dev Buys tickets to participate in a draw. Requests Chainlink to generate random words if all tickets have been bought. Emits {BuyTicket} event for each ticket bought.
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
            listing.chainlinkRequestSent = true;
            uint256 requestID = vrfCoordinator.requestRandomWords(keyHash, subscriptionID, minimumRequestConfirmations, callbackGasLimit, 1);
            chainlinkRequestIDs[requestID] = ID;
            emit RequestWords(ID, requestID);
        }
    }

    /**
     * @dev Receive NFTs the sender won from listings. Emits {ReceiveItem} event for each of the NFT received.
     * @param IDs - IDs of listings to claim NFTs in.
     * @param recipient - Address to send NFTs to. 
     
     * @return tokens - Addresses of tokens received.
     * @return tokenIDs - IDs of tokens received.
     * Note: Returning an array of NFT structs gives me "Stack too deep" error for some reason, so I have to return it this way
     */
    function batchReceiveItems(uint256[] memory IDs, address recipient) external returns(IERC721[] memory tokens, uint256[] memory tokenIDs){
        tokens = new IERC721[](IDs.length);
        tokenIDs = new uint256[](IDs.length);

        for(uint256 i; i < IDs.length; i++){
            uint256 ID = IDs[i];
            Listing storage listing = listings[ID];
            require(listing.winner == msg.sender, "eesee: Caller is not the winner");
            require(!listing.itemClaimed, "eesee: Item has already been claimed");

            tokens[i] = listing.nft.token;
            tokenIDs[i] = listing.nft.tokenID;
            listing.itemClaimed = true;
            listing.nft.token.safeTransferFrom(address(this), recipient, listing.nft.tokenID);

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
        for(uint256 i; i < IDs.length; i++){
            uint256 ID = IDs[i];
            Listing storage listing = listings[ID];
            require(listing.winner != address(0), "eesee: Listing is not filfilled");
            require(listing.owner == msg.sender, "eesee: Caller is not the owner");
            require(!listing.tokensClaimed, "eesee: Tokens have already been claimed");

            listing.tokensClaimed = true;
            uint256 _amount = listing.ticketPrice * listing.maxTickets;
            _amount -= _collectSellFees(_amount, listing.devFee, listing.poolFee);
            amount += _amount;

            emit ReceiveTokens(ID, recipient, _amount);

            if(listing.itemClaimed){
                delete listings[ID];
            }
        }
        //transfer later to save gas
        ESE.safeTransfer(recipient, amount);
    }

    /**
     * @dev Reclaim NFTs from expired listings. Emits {ReclaimItem} event for each listing ID.
     * @param IDs - IDs of listings to reclaim NFTs in.
     * @param recipient - Address to send NFTs to.
     
     * @return tokens - Addresses of tokens reclaimed.
     * @return tokenIDs - IDs of tokens reclaimed.
     * Note: returning an array of NFT structs gives me "Stack too deep" error for some reason, so I have to return it this way
     */
    function batchReclaimItems(uint256[] memory IDs, address recipient) external returns(IERC721[] memory tokens, uint256[] memory tokenIDs){
        tokens = new IERC721[](IDs.length);
        tokenIDs = new uint256[](IDs.length);

        for(uint256 i; i < IDs.length; i++){
            uint256 ID = IDs[i];
            Listing storage listing = listings[ID];
            require(msg.sender == listing.owner, "eesee: Caller is not the owner");
            require(block.timestamp > listing.creationTime + listing.duration, "eesee: Listing has not expired yet");
            require(!listing.chainlinkRequestSent, "eesee: Listing fulfilment is already pending");
            require(!listing.itemClaimed, "eesee: Item has already been claimed");

            tokens[i] = listing.nft.token;
            tokenIDs[i] = listing.nft.tokenID;
            listing.itemClaimed = true;
            listing.nft.token.safeTransferFrom(address(this), recipient, listing.nft.tokenID);

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
        for(uint256 i; i < IDs.length; i++){
            uint256 ID = IDs[i];
            Listing storage listing = listings[ID];
            uint256 ticketsBoughtByAddress = listing.ticketsBoughtByAddress[msg.sender];
            require(ticketsBoughtByAddress > 0, "eesee: No tickets bought");
            require(block.timestamp > listing.creationTime + listing.duration, "eesee: Listing has not expired yet");
            require(!listing.chainlinkRequestSent, "eesee: Listing fulfilment is already pending");

            listing.ticketsBought -= ticketsBoughtByAddress;
            listing.ticketsBoughtByAddress[msg.sender] = 0;

            uint256 _amount = ticketsBoughtByAddress * listing.ticketPrice;
            amount += _amount;

            emit ReclaimTokens(ID, msg.sender, recipient, ticketsBoughtByAddress, _amount);

            if(listing.ticketsBought == 0 && listing.itemClaimed){
                delete listings[ID];
            }
        }
        //transfer later to save some gas
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

    // Note: must be called after nft was minted/transfered
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
        listing.devFee = devFee; // We save fees at the time of listing's creation to not have any control over existing listings' fees
        listing.poolFee = poolFee; // We save fees at the time of listing's creation to not have any control over existing listings' fees
        listing.creationTime = block.timestamp;
        listing.duration = duration;

        emit ListItem(ID, nft, listing.owner, maxTickets, ticketPrice, duration);
    }

    function _collectMintFee() internal {
        ESE.safeTransferFrom(msg.sender, feeCollector, mintFee);
        emit CollectDevFee(feeCollector, mintFee);
    }

    function _collectSellFees(uint256 amount, uint256 _devFee, uint256 _poolFee) internal returns(uint256 feeAmount){
        uint256 devFeeAmount = amount * _devFee / 1 ether;
        if(devFeeAmount > 0){
            ESE.safeTransfer(feeCollector, devFeeAmount);
            feeAmount += devFeeAmount;
            emit CollectDevFee(feeCollector, devFeeAmount);
        }

        uint256 poolFeeAmount = amount * _poolFee / 1 ether;
        if(poolFeeAmount > 0){
            ESE.safeTransfer(rewardPool, poolFeeAmount);
            feeAmount += poolFeeAmount;
            emit CollectPoolFee(rewardPool, poolFeeAmount);
        }
    }

    /**
     * @dev This function is called by Chainlink. Chooses listing winner and emits {FulfillListing} event.
     * @param requestID - Chainlink request ID.
     * @param randomWords - Random values sent by Chainlink.
     */
    function fulfillRandomWords(uint256 requestID, uint256[] memory randomWords) internal override {
        uint256 ID = chainlinkRequestIDs[requestID];
        Listing storage listing = listings[ID];

        uint256 chosenTicket = randomWords[0] % listing.maxTickets;
        listing.winner = listing.ticketIDBuyer[chosenTicket];

        delete chainlinkRequestIDs[requestID];
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
     * @dev Changes mintFee. Emits {ChangeMintFee} event.
     * @param _mintFee - New mintFee.
     * Note: This function can only be called by owner.
     */
    function changeMintFee(uint256 _mintFee) external onlyOwner {
        emit ChangeMintFee(mintFee, _mintFee);
        mintFee = _mintFee;
    }

    /**
     * @dev Changes devFee. Emits {ChangeDevFee} event.
     * @param _devFee - New devFee.
     * Note: This function can only be called by owner.
     */
    function changeDevFee(uint256 _devFee) external onlyOwner {
        require(_devFee + poolFee <= 0.4 ether, "eesee: Can't set fees to more than 40%");

        emit ChangeDevFee(devFee, _devFee);
        devFee = _devFee;
    }

    /**
     * @dev Changes poolFee. Emits {ChangePoolFee} event.
     * @param _poolFee - New poolFee.
     * Note: This function can only be called by owner.
     */
    function changePoolFee(uint256 _poolFee) external onlyOwner {
        require(devFee + _poolFee <= 0.4 ether, "eesee: Can't set fees to more than 40%");

        emit ChangePoolFee(poolFee, _poolFee);
        poolFee = _poolFee;
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

    /**
     * @dev Fund function for Chainlink's VRF V2 subscription.
     * @param amount - Amount of LINK to fund subscription with.
     */
    function fund(uint96 amount) external {
        IERC20(address(LINK)).safeTransferFrom(msg.sender, address(this), amount);
        LINK.transferAndCall(
            address(vrfCoordinator),
            amount,
            abi.encode(subscriptionID)
        );
    }
}