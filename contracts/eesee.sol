// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/Ieesee.sol";
import "./interfaces/IUniswapV2Router01.sol";

contract eesee is Ieesee, VRFConsumerBaseV2, ERC721Holder, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    ///@dev An array of all existing listings.
    Listing[] public listings;
    ///@dev An array of all existing drops listings.
    Drop[] public drops;
    ///@dev Maps chainlink request ID to listing ID.
    mapping(uint256 => uint256) private chainlinkRequestIDs;

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
    ///@dev The fee for chainlink VRF is shared between ticket buyers & eesee team. [1 ether == 100%]
    uint256 public chainlinkFeeShare = 0.5 ether;
    ///@dev Denominator for fee & maxTicketsBoughtByAddress variables.
    uint256 private constant denominator = 1 ether;

    ///@dev Chainlink token.
    LinkTokenInterface immutable public LINK;
    ///@dev Chainlink VRF V2 coordinator.
    VRFCoordinatorV2Interface immutable public vrfCoordinator;
    ///@dev Chainlink VRF V2 subscription ID.
    uint64 immutable public subscriptionID;
    ///@dev Chainlink VRF V2 key hash to call requestRandomWords() with.
    bytes32 immutable public keyHash;
    ///@dev Chainlink VRF V2 gas lane to call requestRandomWords() with unhashed.
    uint256 immutable public keyHashGasLane;
    ///@dev Chainlink VRF V2 request confirmations.
    uint16 immutable public minimumRequestConfirmations;
    ///@dev Chainlink VRF V2 gas limit to call fulfillRandomWords().
    uint32 immutable private callbackGasLimit;

    ///@dev The Royalty Engine is a contract that provides an easy way for any marketplace to look up royalties for any given token contract.
    IRoyaltyEngineV1 immutable public royaltyEngine;
    ///@dev UniswapV2 router is used for ETH => LINK conversions. We use UniswapV2 with predefined {route} to have as little contol over ETH as possible.
    IUniswapV2Router01 immutable public UniswapV2Router;
    address[] public route;

    ///@dev 1inch router used for token swaps.
    address immutable public OneInchRouter;

    receive() external payable {
        //Reject deposits from EOA
        if (msg.sender == tx.origin) revert EthDepositRejected();
    }

    constructor(
        IERC20 _ESE,
        IeeseeMinter _minter,
        address _feeCollector,
        IRoyaltyEngineV1 _royaltyEngine,
        ChainlinkContructorArgs memory chainlinkArgs,
        address _WETH,
        IUniswapV2Router01 _UniswapV2Router,
        address _OneInchRouter
    ) VRFConsumerBaseV2(chainlinkArgs.vrfCoordinator) {
        ESE = _ESE;
        minter = _minter;
        feeCollector = _feeCollector;
        royaltyEngine = _royaltyEngine;

        // ChainLink stuff. Create subscription for VRF V2.
        vrfCoordinator = VRFCoordinatorV2Interface(chainlinkArgs.vrfCoordinator);
        subscriptionID = vrfCoordinator.createSubscription();
        vrfCoordinator.addConsumer(subscriptionID, address(this));
        LINK = chainlinkArgs.LINK;
        keyHash = chainlinkArgs.keyHash;
        keyHashGasLane = chainlinkArgs.keyHashGasLane;
        minimumRequestConfirmations = chainlinkArgs.minimumRequestConfirmations;
        callbackGasLimit = chainlinkArgs.callbackGasLimit;

        UniswapV2Router = _UniswapV2Router;
        route = new address[](2);
        route[0] = _WETH;
        route[1] = address(LINK);

        OneInchRouter = _OneInchRouter;

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
        if(nfts.length != maxTickets.length || maxTickets.length != ticketPrices.length || ticketPrices.length != durations.length)
            revert InvalidArrayLengths();
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
     * @return token - NFT minted.
     * Note This function costs less than mintAndListItemWithDeploy() but does not deploy additional NFT collection contract
     */
    function mintAndListItem(
        string memory tokenURI, 
        uint256 maxTickets, 
        uint256 ticketPrice, 
        uint256 duration,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external returns(uint256 ID, NFT memory token){
        string[] memory tokenURIs = new string[](1);
        tokenURIs[0] = tokenURI;
        
        (IERC721 collection, uint256[] memory tokenIDs) = minter.mintToPublicCollection(1, tokenURIs, royaltyReceiver, royaltyFeeNumerator);
        token = NFT(collection, tokenIDs[0]);
        ID = _listItem(token, maxTickets, ticketPrice, duration);
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
        if(maxTickets.length != ticketPrices.length || maxTickets.length != durations.length) revert InvalidArrayLengths();
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
     * @return token - NFT minted.
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
    ) external returns(uint256 ID, NFT memory token){
        (IERC721 collection, uint256[] memory tokenIDs) = minter.mintToPrivateCollection(1, name, symbol, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator);
        token = NFT(collection, tokenIDs[0]);
        ID = _listItem(token, maxTickets, ticketPrice, duration);
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
        if(maxTickets.length != ticketPrices.length || maxTickets.length != durations.length) revert InvalidArrayLengths();
        (collection, tokenIDs) = minter.mintToPrivateCollection(maxTickets.length, name, symbol, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator);
        
        IDs = new uint256[](maxTickets.length);
        for(uint256 i; i < maxTickets.length; i++){
            IDs[i] = _listItem(NFT(collection, tokenIDs[i]), maxTickets[i], ticketPrices[i], durations[i]);
        }
    }

    /**
     * @dev Buys tickets to participate in a draw. Requests Chainlink to generate random words if all tickets have been bought. Emits {BuyTicket} event for each ticket bought.
     * @param ID - ID of a listing to buy tickets for.
     * @param amount - Amount of tickets to buy. A single address can't buy more than {maxTicketsBoughtByAddress} of all tickets. 
     
     * @return tokensSpent - ESE tokens spent.
        Note: {chainlinkCostPerTicket(ID)} of ETH must be sent with this transaction to pay for Chainlink VRF call.
     */
    function buyTickets(uint256 ID, uint256 amount) external payable returns(uint256 tokensSpent){
        if(msg.value != chainlinkCostPerTicket(ID)) revert InvalidMsgValue();
        tokensSpent = _buyTickets(ID, amount);
        ESE.safeTransferFrom(msg.sender, address(this), tokensSpent);
    }

    /**
     * @dev Buys tickets with any token using 1inch'es router and swapping it for ESE. Requests Chainlink to generate random words if all tickets have been bought. Emits {BuyTicket} event for each ticket bought.
     * @param ID - ID of a listing to buy tickets for.
     * @param swapData - Data for 1inch swap. 
     
     * @return tokensSpent - Tokens spent.
     * @return ticketsBought - Tickets bought.
        Note: Additionaly {chainlinkCostPerTicket(ID)} of ETH must be sent with this transaction to pay for Chainlink VRF call.
     */
    function buyTicketsWithSwap(uint256 ID, bytes calldata swapData) external nonReentrant payable returns(uint256 tokensSpent, uint256 ticketsBought){
        (,IAggregationRouterV5.SwapDescription memory desc,) = abi.decode(swapData[4:], (address, IAggregationRouterV5.SwapDescription, bytes));
        if(
            bytes4(swapData[:4]) != IAggregationRouterV5.swap.selector || 
            desc.srcToken == ESE || 
            desc.dstToken != ESE || 
            desc.amount == 0 ||
            desc.dstReceiver != address(this)
        ) revert InvalidSwapDescription();

        bool isETH = (address(desc.srcToken) == address(0) || address(desc.srcToken) == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE));
        if(isETH){
            if(msg.value != desc.amount + chainlinkCostPerTicket(ID)) revert InvalidMsgValue();
        }else{
            if(msg.value != chainlinkCostPerTicket(ID)) revert InvalidMsgValue();
            desc.srcToken.safeTransferFrom(msg.sender, address(this), desc.amount);
            desc.srcToken.approve(OneInchRouter, desc.amount);
        }

        uint256 returnAmount;
        {
        (bool success, bytes memory data) = OneInchRouter.call{value: msg.value}(swapData);
        if(!success) revert SwapNotSuccessful(); 
        (returnAmount, tokensSpent) = abi.decode(data, (uint256, uint256));
        }

        Listing storage listing = listings[ID];
        ticketsBought = returnAmount / listing.ticketPrice;
        _buyTickets(ID, ticketsBought);

        // Refund dust
        uint256 ESEPaid = ticketsBought * listing.ticketPrice;
        if(returnAmount > ESEPaid){
            ESE.safeTransfer(address(msg.sender), returnAmount - ESEPaid); 
        }
        if(desc.amount > tokensSpent){
            if(isETH){
                (bool success, ) = msg.sender.call{value: desc.amount - tokensSpent}("");
                if(!success) revert TransferNotSuccessful();
            }else{
                desc.srcToken.safeTransfer(address(msg.sender), desc.amount - tokensSpent);
            }   
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
        if(earningsCollector == address(0)) revert InvalidEarningsCollector();
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
        if(quantity == 0) revert InvalidQuantity();
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
        if(recipient == address(0)) revert InvalidRecipient();
        collections = new IERC721[](IDs.length);
        tokenIDs = new uint256[](IDs.length);

        for(uint256 i; i < IDs.length; i++){
            uint256 ID = IDs[i];
            Listing storage listing = listings[ID];

            if(msg.sender != listing.winner) revert CallerNotWinner(ID);
            if(listing.itemClaimed) revert ItemAlreadyClaimed(ID);

            collections[i] = listing.nft.collection;
            tokenIDs[i] = listing.nft.tokenID;
            listing.itemClaimed = true;
            listing.nft.collection.safeTransferFrom(address(this), recipient, listing.nft.tokenID);

            emit ReceiveItem(ID, listing.nft, recipient);

            if(listing.tokensClaimed) delete listings[ID];
        }
    }

    /**
     * @dev Receive ESE the sender has earned from listings. Emits {ReceiveTokens} event for each of the claimed listing.
     * @param IDs - IDs of listings to claim tokens in.
     * @param recipient - Address to send tokens to.
     
     * @return amount - ESE received.
     */
    function batchReceiveTokens(uint256[] memory IDs, address recipient) external returns(uint256 amount){
        if(recipient == address(0)) revert InvalidRecipient();
        for(uint256 i; i < IDs.length; i++){
            uint256 ID = IDs[i];
            Listing storage listing = listings[ID];

            if(listing.winner == address(0)) revert ListingNotFulfilled(ID);
            if(msg.sender != listing.owner) revert CallerNotOwner(ID);
            if(listing.tokensClaimed) revert TokensAlreadyClaimed(ID);

            listing.tokensClaimed = true;
            uint256 _amount = listing.ticketPrice * listing.maxTickets;
            _amount -= _collectRoyalties(_amount, listing.nft, listing.owner);
            _amount -= _collectFee(_amount, listing.fee);
            amount += _amount;

            emit ReceiveTokens(ID, recipient, _amount);

            if(listing.itemClaimed) delete listings[ID];
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
        if(recipient == address(0)) revert InvalidRecipient();
        collections = new IERC721[](IDs.length);
        tokenIDs = new uint256[](IDs.length);

        for(uint256 i; i < IDs.length; i++){
            uint256 ID = IDs[i];
            Listing storage listing = listings[ID];

            if(msg.sender != listing.owner) revert CallerNotOwner(ID);
            if(block.timestamp <= listing.creationTime + listing.duration) revert ListingNotExpired(ID);
            if(listing.itemClaimed) revert ItemAlreadyClaimed(ID);
            if(listing.winner != address(0)) revert ListingAlreadyFulfilled(ID);

            collections[i] = listing.nft.collection;
            tokenIDs[i] = listing.nft.tokenID;
            listing.itemClaimed = true;
            listing.nft.collection.safeTransferFrom(address(this), recipient, listing.nft.tokenID);

            emit ReclaimItem(ID, listing.nft, recipient);

            if(listing.ticketsBought == 0) delete listings[ID];
        }
    }

    /**
     * @dev Reclaim ESE from expired listings. Emits {ReclaimTokens} event for each listing ID.
     * @param IDs - IDs of listings to reclaim tokens in.
     * @param recipient - Address to send tokens to.
     
     * @return amount - ESE received.
     */
    function batchReclaimTokens(uint256[] memory IDs, address recipient) external nonReentrant returns(uint256 amount){
        if(recipient == address(0)){
            revert InvalidRecipient();
        }
        for(uint256 i; i < IDs.length; i++){
            uint256 ID = IDs[i];
            Listing storage listing = listings[ID];
            uint256 ticketsBoughtByAddress = listing.ticketsBoughtByAddress[msg.sender];

            if(ticketsBoughtByAddress == 0) revert NoTicketsBought(ID);
            if(block.timestamp <= listing.creationTime + listing.duration) revert ListingNotExpired(ID);
            if(listing.winner != address(0)) revert ListingAlreadyFulfilled(ID);

            listing.ticketsBought -= ticketsBoughtByAddress;
            listing.ticketsBoughtByAddress[msg.sender] = 0;

            uint256 _amount = ticketsBoughtByAddress * listing.ticketPrice;
            amount += _amount;

            emit ReclaimTokens(ID, msg.sender, recipient, ticketsBoughtByAddress, _amount);

            uint256 chainlinkFeeRefund = chainlinkCostPerTicket(ID);
            if(listing.ticketsBought == 0 && listing.itemClaimed) delete listings[ID];

            (bool success, ) = msg.sender.call{value: chainlinkFeeRefund}("");
            if(!success) revert TransferNotSuccessful();
        }
        // Transfer later to save some gas
        ESE.safeTransfer(recipient, amount);
    }

    // ============ Getters ============
    /**
     * @dev Additional ETH that needs to be passed with buyTickets to pay for Chainlink gas costs.
     * @param ID - ID of listing to check.

     *@return ETHPerTicket - ETH gas amount that has to be paid for each ticket bought.
     */
    function chainlinkCostPerTicket(uint256 ID) public view returns(uint256 ETHPerTicket){
        uint256 maxETHCost = keyHashGasLane * (200000 + callbackGasLimit); // 200000 is Verification gas
        ETHPerTicket = maxETHCost * chainlinkFeeShare / listings[ID].maxTickets / denominator;
    }

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
        if(duration < minDuration) revert DurationTooLow(minDuration);
        if(duration > maxDuration) revert DurationTooHigh(maxDuration);
        if(maxTickets < 2) revert MaxTicketsTooLow();
        if(ticketPrice == 0) revert TicketPriceTooLow();

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

    function _buyTickets(uint256 ID, uint256 amount) internal returns(uint256 tokensSpent){
        if(amount == 0) revert BuyAmountTooLow();
        Listing storage listing = listings[ID];
        if(listing.owner == address(0)) revert ListingNotExists(ID);
        if(block.timestamp > listing.creationTime + listing.duration) revert ListingExpired(ID);

        tokensSpent = listing.ticketPrice * amount;

        for(uint256 i; i < amount; i++){
            emit BuyTicket(ID, msg.sender, listing.ticketsBought, listing.ticketPrice);
            listing.ticketIDBuyer[listing.ticketsBought] = msg.sender;
            listing.ticketsBought += 1;
        }
        listing.ticketsBoughtByAddress[msg.sender] += amount;

        //Allow buy single tickets even if bought amount is more than maxTicketsBoughtByAddress
        if(listing.ticketsBoughtByAddress[msg.sender] > 1){
            if(listing.ticketsBoughtByAddress[msg.sender] * denominator / listing.maxTickets > maxTicketsBoughtByAddress) revert MaxTicketsBoughtByAddress(msg.sender);
        }
        if(listing.ticketsBought > listing.maxTickets) revert AllTicketsBought();

        if(listing.ticketsBought == listing.maxTickets){
            uint256 requestID = vrfCoordinator.requestRandomWords(keyHash, subscriptionID, minimumRequestConfirmations, callbackGasLimit, 1);
            chainlinkRequestIDs[requestID] = ID;
            emit RequestWords(ID, requestID);
        }
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
        if(feeCollector == address(0)) return 0;
        feeAmount = amount * _fee / denominator;
        if(feeAmount > 0){
            ESE.safeTransfer(feeCollector, feeAmount);
            emit CollectFee(feeCollector, feeAmount);
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

        if(block.timestamp > listing.creationTime + listing.duration) revert ListingExpired(ID);

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
        if(_maxTicketsBoughtByAddress > denominator) revert MaxTicketsBoughtByAddressTooHigh();

        emit ChangeMaxTicketsBoughtByAddress(maxTicketsBoughtByAddress, _maxTicketsBoughtByAddress);
        maxTicketsBoughtByAddress = _maxTicketsBoughtByAddress;
    }

    /**
     * @dev Changes fee. Emits {ChangeFee} event.
     * @param _fee - New fee.
     * Note: This function can only be called by owner.
     */
    function changeFee(uint256 _fee) external onlyOwner {
        if(_fee > denominator / 2) revert FeeTooHigh();

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

    /**
     * @dev Changes chainlinkFeeShare. Emits {ChangeChainlinkFeeShare} event.
     * @param _chainlinkFeeShare - New chainlink fee share.
     * Note: This function can only be called by owner.
     */
    function changeChainlinkFeeShare(uint256 _chainlinkFeeShare) external onlyOwner {
        if(_chainlinkFeeShare > denominator) revert ChainlinkFeeTooHigh();

        emit ChangeChainlinkFeeShare(chainlinkFeeShare, _chainlinkFeeShare);
        chainlinkFeeShare = _chainlinkFeeShare;
    }

    /**
     * @dev Fund function for Chainlink's VRF V2 subscription.
     * @param amount - Amount of LINK to fund subscription with.
     * @param amountOutMin - Min amount of Chainlink that can be received from swap.
     */
    function fund(uint256 _amount, uint256 amountOutMin) external returns (uint96 amount){
        if(_amount > 0){
            IERC20(address(LINK)).safeTransferFrom(msg.sender, address(this), _amount);
        }
        
        uint256 balance = address(this).balance;
        if(balance > 0){
            uint256[] memory amounts = UniswapV2Router.swapExactETHForTokens{value: balance}(amountOutMin, route, address(this), block.timestamp);
            _amount += amounts[1];
        }

        if(_amount == 0 || _amount > type(uint96).max) revert InvalidAmount();
        amount = uint96(_amount);

        LINK.transferAndCall(
            address(vrfCoordinator),
            amount,
            abi.encode(subscriptionID)
        );
    }
}