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
//TODO: comments
contract eesee is IEesee, VRFConsumerBaseV2, ERC721Holder, Ownable {
    using SafeERC20 for IERC20;

    Listing[] public listings;
    //chainlink request ID => listing ID
    mapping(uint256 => uint256) private chainlinkRequestIDs;

    IERC20 public immutable eeseeToken;
    address public immutable rewardPool;
    eeseeNFT public immutable publicMinter;

    uint256 public minDuration = 1 days;
    uint256 public maxDuration = 30 days;
    uint256 public maxTicketsBoughtByAddress = 0.20 ether;
    uint256 public mintFee = 10 ether;//Note: fixed fee, not in %
    uint256 public devFee = 0.02 ether;//[1 ether == 100%]
    uint256 public poolFee = 0.08 ether;//[1 ether == 100%]
    address public feeCollector;

    LinkTokenInterface immutable public LINK;
    VRFCoordinatorV2Interface immutable public vrfCoordinator;
    uint64 immutable public subscriptionID;

    constructor(
        IERC20 _eeseeToken,
        address _rewardPool,
        string memory baseURI,
        address _feeCollector,
        address _vrfCoordinator, 
        LinkTokenInterface _LINK
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        eeseeToken = _eeseeToken;
        rewardPool = _rewardPool;
        // Deploy NFT contract for single item mint feature
        publicMinter = new eeseeNFT("ESE Public Collection", "ESE-Public", baseURI);

        feeCollector = _feeCollector;

        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionID = vrfCoordinator.createSubscription();
        vrfCoordinator.addConsumer(subscriptionID, address(this));
        LINK = _LINK;
    }

    // ============ External Methods ============

    //TODO:batch list items
    function listItem(NFT memory nft, uint256 maxTickets, uint256 ticketPrice, uint256 duration) external returns(uint256 ID){
        nft.token.safeTransferFrom(msg.sender, address(this), nft.tokenID);
        ID = _listItem(nft, maxTickets, ticketPrice, duration);
    }

    //Note: Don't need name because it will be stored in metadata
    //Note costs less than mintAndListItemsWithDeploy but does not deploy its own contract
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

    //Note: More expensive but deploys NFT contract
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

    function buyTickets(uint256 ID, uint256 amount) external returns(uint256 tokensSpent){
        require(amount > 0, "eesee: Amount must be above zero");
        Listing storage listing = listings[ID];
        require(listing.owner != address(0), "eesee: Listing does not exist");
        require(block.timestamp <= listing.creationTime + listing.duration, "eesee: Listing has already expired");
        require(!listing.fulfilmentPending, "eesee: Listing fulfilment is already pending");

        tokensSpent = listing.ticketPrice * amount;
        eeseeToken.safeTransferFrom(msg.sender, address(this), tokensSpent);

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
            listing.fulfilmentPending = true;
            //ETHEREUM CONFIG
            //0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef - 200 gwei hash
            //13 - requestConfirmations (13 for POS)
            //200000 - callbackGasLimit //TODO: test if this is enough
            //1 - numWords
            uint256 requestID = vrfCoordinator.requestRandomWords(0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef, subscriptionID, 13, 200000, 1);
            chainlinkRequestIDs[requestID] = ID;
            emit RequestWords(ID, requestID);
        }
    }

    function batchReceiveItems(uint256[] memory IDs, address recipient) external returns(NFT[] memory NFTs){
        NFTs = new NFT[](IDs.length);
        for(uint256 i; i < IDs.length; i++){
            uint256 ID = IDs[i];
            Listing storage listing = listings[ID];
            require(listing.winner == msg.sender, "eesee: Caller is not the winner");
            require(!listing.itemClaimed, "eesee: Item has already been claimed");

            NFTs[i] = listing.nft;
            listing.itemClaimed = true;
            listing.nft.token.safeTransferFrom(address(this), recipient, listing.nft.tokenID);

            emit ReceiveItem(ID, listing.nft, recipient);

            if(listing.tokensClaimed){
                delete listings[ID];
            }
        }
    }

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
        eeseeToken.safeTransfer(recipient, amount);
    }

    function batchReclaimItems(uint256[] memory IDs, address recipient) external returns(NFT[] memory NFTs){
        NFTs = new NFT[](IDs.length);
        for(uint256 i; i < IDs.length; i++){
            uint256 ID = IDs[i];
            Listing storage listing = listings[ID];
            require(msg.sender == listing.owner, "eesee: Caller is not the owner");
            require(block.timestamp > listing.creationTime + listing.duration, "eesee: Listing has not expired yet");
            require(!listing.fulfilmentPending, "eesee: Listing fulfilment is already pending");
            require(!listing.itemClaimed, "eesee: Item has already been claimed");

            NFTs[i] = listing.nft;
            listing.itemClaimed = true;
            listing.nft.token.safeTransferFrom(address(this), recipient, listing.nft.tokenID);

            emit ReclaimItem(ID, listing.nft, recipient);

            if(listing.ticketsBought == 0){
                delete listings[ID];
            }
        }
    }

    function batchReclaimTokens(uint256[] memory IDs, address recipient) external returns(uint256 amount){
        for(uint256 i; i < IDs.length; i++){
            uint256 ID = IDs[i];
            Listing storage listing = listings[ID];
            uint256 ticketsBoughtByAddress = listing.ticketsBoughtByAddress[msg.sender];
            require(ticketsBoughtByAddress > 0, "eesee: No tickets bought");
            require(block.timestamp > listing.creationTime + listing.duration, "eesee: Listing has not expired yet");
            require(!listing.fulfilmentPending, "eesee: Listing fulfilment is already pending");

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
        eeseeToken.safeTransfer(recipient, amount);
    }

    // ============ Getters ============

    function getListingsLength() external view returns(uint256 length) {
        length = listings.length;
    }

    function getListingTicketIDBuyer(uint256 ID, uint256 ticket) external view returns(address) {
        return listings[ID].ticketIDBuyer[ticket];
    }
    
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

        ID = listings.length + 1;
        Listing storage listing = listings[ID];
        listing.ID = ID;
        listing.nft = nft;
        listing.owner = msg.sender;
        listing.maxTickets = maxTickets;
        listing.ticketPrice = ticketPrice;
        listing.devFee = devFee; // We save fees at the time of listing's creation to not have control over existing listings' fees
        listing.poolFee = poolFee; // We save fees at the time of listing's creation to not have control over existing listings' fees
        listing.creationTime = block.timestamp;
        listing.duration = duration;

        emit ListItem(ID, nft, listing.owner, maxTickets, ticketPrice, duration);
    }

    function _collectMintFee() internal {
        eeseeToken.safeTransferFrom(msg.sender, feeCollector, mintFee);
        emit CollectDevFee(feeCollector, mintFee);
    }

    function _collectSellFees(uint256 amount, uint256 _devFee, uint256 _poolFee) internal returns(uint256 feeAmount){
        uint256 devFeeAmount = amount * _devFee / 1 ether;
        if(devFeeAmount > 0){
            eeseeToken.safeTransfer(feeCollector, devFeeAmount);
            feeAmount += devFeeAmount;
            emit CollectDevFee(feeCollector, devFeeAmount);
        }

        uint256 poolFeeAmount = amount * _poolFee / 1 ether;
        if(poolFeeAmount > 0){
            eeseeToken.safeTransfer(rewardPool, poolFeeAmount);
            feeAmount += poolFeeAmount;
            emit CollectPoolFee(rewardPool, poolFeeAmount);
        }
    }

    function fulfillRandomWords(uint256 requestID, uint256[] memory randomWords) internal override {
        uint256 ID = chainlinkRequestIDs[requestID];
        Listing storage listing = listings[ID];

        uint256 chosenTicket = randomWords[0] % listing.maxTickets;
        listing.winner = listing.ticketIDBuyer[chosenTicket];

        delete chainlinkRequestIDs[requestID];
        emit FulfillListing(ID, listing.nft, listing.winner);
    }

    // ============ Admin Methods ============

    function changeMinDuration(uint256 _minDuration) external onlyOwner {
        emit ChangeMinDuration(minDuration, _minDuration);
        minDuration = _minDuration;
    }
    function changeMaxDuration(uint256 _maxDuration) external onlyOwner {
        emit ChangeMaxDuration(maxDuration, _maxDuration);
        maxDuration = _maxDuration;
    }
    //Note: Even if maxTicketsBoughtByAddress == 0 users can still buy 1 ticket.
    function changeMaxTicketsBoughtByAddress(uint256 _maxTicketsBoughtByAddress) external onlyOwner {
        require(_maxTicketsBoughtByAddress <= 1 ether, "eesee: Can't set maxTicketsBoughtByAddress to more than 100%");

        emit ChangeMaxTicketsBoughtByAddress(maxTicketsBoughtByAddress, _maxTicketsBoughtByAddress);
        maxTicketsBoughtByAddress = _maxTicketsBoughtByAddress;
    }
    function changeMintFee(uint256 _mintFee) external onlyOwner {
        emit ChangeMintFee(mintFee, _mintFee);
        mintFee = _mintFee;
    }
    function changeDevFee(uint256 _devFee) external onlyOwner {
        require(_devFee + poolFee <= 0.4 ether, "eesee: Can't set fees to more than 40%");

        emit ChangeDevFee(devFee, _devFee);
        devFee = _devFee;
    }
    function changePoolFee(uint256 _poolFee) external onlyOwner {
        require(devFee + _poolFee <= 0.4 ether, "eesee: Can't set fees to more than 40%");

        emit ChangePoolFee(poolFee, _poolFee);
        poolFee = _poolFee;
    }
    function changeFeeCollector(address _feeCollector) external onlyOwner{
        emit ChangeFeeCollector(feeCollector, _feeCollector);
        feeCollector = _feeCollector;
    }

    function fund(uint96 amount) external {
        IERC20(address(LINK)).safeTransferFrom(msg.sender, address(this), amount);
        LINK.transferAndCall(
            address(vrfCoordinator),
            amount,
            abi.encode(subscriptionID)
        );
    }
}