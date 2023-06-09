// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "./IeeseeMinter.sol";
import "./IeeseeStaking.sol";
import "./IRoyaltyEngineV1.sol";
import "./IAggregationRouterV5.sol";

interface Ieesee {
    /**
     * @dev NFT:
     * {token} - IERC721 contract address.
     * {tokenID} - Token ID of NFT. 
     */
    struct NFT {
        IERC721 collection;
        uint256 tokenID;
    }

    /**
     * @dev Listing:
     * {ID} - Id of the Listing, starting from 1.
     * {nft} - NFT sold in this listing. 
     * {owner} - Listing creator.
     * {maxTickets} - Amount of tickets sold in this listing. 
     * {ticketIDBuyer} - The buyer of the specified ticket.
     * {ticketsBoughtByAddress} - Amount of tickets bought by address.
     * {ticketPrice} - Price of a single ticket.
     * {ticketsBought} - Amount of tickets bought.
     * {fee} - Fee sent to {feeSplitter}.
     * {creationTime} - Listing creation time.
     * {duration} - Listing duration.
     * {winner} - Selected winner.
     * {itemClaimed} - Is NFT claimed/reclaimed.
     * {tokensClaimed} - Are tokens claimed.
     */
    struct Listing {
        uint256 ID;
        NFT nft;
        address owner;
        uint256 maxTickets;
        mapping(uint256 => address) ticketIDBuyer;
        mapping(address => uint256) ticketsBoughtByAddress;
        uint256 ticketPrice;
        uint256 ticketsBought;
        uint256 fee;
        uint256 creationTime;
        uint256 duration;
        address winner;
        bool itemClaimed;
        bool tokensClaimed;
    }

    /**
     * @dev Drop:
     * {ID} - Id of the Drop, starting from 1.
     * {collection} - IERC721 contract address.
     * {earningsCollector} - Address that collects earnings from this drop.
     * {fee} - Fee sent to {feeSplitter}.
     */
    struct Drop {
        uint256 ID;
        IERC721 collection;
        address earningsCollector;
        uint256 fee;
    }

    ///@dev Because of the Stack too deep error, we combine some constructor arguments into a single stuct
    struct ChainlinkContructorArgs{
        address vrfCoordinator;
        LinkTokenInterface LINK;
        bytes32 keyHash;
        uint256 keyHashGasLane;
        uint16 minimumRequestConfirmations;
        uint32 callbackGasLimit;
        AggregatorV3Interface LINK_ETH_DataFeed;
    }

    event ListItem(
        uint256 indexed ID,
        NFT indexed nft,
        address indexed owner,
        uint256 maxTickets, 
        uint256 ticketPrice,
        uint256 duration
    );

    event BuyTicket(
        uint256 indexed ID,
        address indexed buyer,
        uint256 indexed ticketID,
        uint256 ticketPrice
    );


    event RequestWords(
        uint256 indexed ID,
        uint256 requestID
    );

    event FulfillListing(
        uint256 indexed ID,
        NFT indexed nft,
        address indexed winner
    );


    event ReceiveItem(
        uint256 indexed ID,
        NFT indexed nft,
        address indexed recipient
    );

    event ReceiveTokens(
        uint256 indexed ID,
        address indexed recipient,
        uint256 amount
    );


    event ReclaimItem(
        uint256 indexed ID,
        NFT indexed nft,
        address indexed recipient
    );

    event ReclaimTokens(
        uint256 indexed ID,
        address indexed sender,
        address indexed recipient,
        uint256 tickets,
        uint256 amount
    );


    event CollectRoyalty(
        address indexed recipient,
        uint256 amount
    );

    event CollectFee(
        address indexed to,
        uint256 amount
    );


    event ChangeMinDuration(
        uint256 indexed previousMinDuration,
        uint256 indexed newMinDuration
    );

    event ChangeMaxDuration(
        uint256 indexed previousMaxDuration,
        uint256 indexed newMaxDuration
    );

    event ChangeMaxTicketsBoughtByAddress(
        uint256 indexed previousMaxTicketsBoughtByAddress,
        uint256 indexed newMaxTicketsBoughtByAddress
    );

    event ChangeFee(
        uint256 indexed previousFee, 
        uint256 indexed newFee
    );

    event ChangeChainlinkFeeShare(
        uint256 indexed previousChainlinkFeeShare, 
        uint256 indexed newChainlinkFeeShare
    );

    event ListDrop(
        uint256 indexed ID, 
        IERC721 indexed collection, 
        address indexed earningsCollector
    );
    event MintDrop(
        uint256 indexed ID, 
        NFT indexed nft,
        address indexed sender,
        uint256 mintFee
    );

    event ChainlinkFunded(
        uint256 indexed subscriptionID, 
        uint256 amount
    );

    error CallerNotOwner(uint256 ID);
    error CallerNotWinner(uint256 ID);

    error ItemAlreadyClaimed(uint256 ID);
    error TokensAlreadyClaimed(uint256 ID);

    error ListingAlreadyFulfilled(uint256 ID);
    error ListingNotFulfilled(uint256 ID);
    error ListingExpired(uint256 ID);
    error ListingNotExpired(uint256 ID);
    error ListingNotExists(uint256 ID);

    error DurationTooLow(uint256 minDuration);
    error DurationTooHigh(uint256 maxDuration);
    error MaxTicketsTooLow();
    error TicketPriceTooLow();
    error BuyAmountTooLow();
    error FeeTooHigh();
    error ChainlinkFeeTooHigh();
    error MaxTicketsBoughtByAddressTooHigh();

    error AllTicketsBought();
    error NoTicketsBought(uint256 ID);
    error MaxTicketsBoughtByAddress(address _address);

    error InvalidConstructor();
    error InvalidArrayLengths();
    error InvalidSwapDescription();
    error InvalidMsgValue();
    error InvalidEarningsCollector();
    error InvalidQuantity();
    error InvalidRecipient();
    error InvalidAnswer();
    error InvalidAmount();
    error InsufficientETH();

    error SwapNotSuccessful();
    error TransferNotSuccessful();
    error EthDepositRejected();

    function listings(uint256) external view returns(
        uint256 ID,
        NFT memory nft,
        address owner,
        uint256 maxTickets,
        uint256 ticketPrice,
        uint256 ticketsBought,
        uint256 fee,
        uint256 creationTime,
        uint256 duration,
        address winner,
        bool itemClaimed,
        bool tokensClaimed
    );

    function drops(uint256) external view returns(
        uint256 ID,
        IERC721 collection,
        address earningsCollector,
        uint256 fee
    );

    function ESE() external view returns(IERC20);
    function staking() external view returns(IeeseeStaking);
    function minter() external view returns(IeeseeMinter);

    function minDuration() external view returns(uint256);
    function maxDuration() external view returns(uint256);
    function maxTicketsBoughtByAddress() external view returns(uint256);
    function fee() external view returns(uint256);
    function feeSplitter() external view returns(address);
    function chainlinkFeeShare() external view returns(uint256);

    function LINK() external view returns(LinkTokenInterface);
    function vrfCoordinator() external view returns(VRFCoordinatorV2Interface);
    function subscriptionID() external view returns(uint64);
    function keyHash() external view returns(bytes32);
    function minimumRequestConfirmations() external view returns(uint16);

    function royaltyEngine() external view returns(IRoyaltyEngineV1);
    function OneInchRouter() external view returns(address);

    function listItem(
        NFT memory nft, 
        uint256 maxTickets, 
        uint256 ticketPrice, 
        uint256 duration
    ) external returns(uint256 ID);
    function listItems(
        NFT[] memory nfts, 
        uint256[] memory maxTickets, 
        uint256[] memory ticketPrices, 
        uint256[] memory durations
    ) external returns(uint256[] memory IDs);

    function mintAndListItem(
        string memory tokenURI, 
        uint256 maxTickets, 
        uint256 ticketPrice, 
        uint256 duration,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external returns(uint256 ID, NFT memory token);
    function mintAndListItems(
        string[] memory tokenURIs, 
        uint256[] memory maxTickets, 
        uint256[] memory ticketPrices, 
        uint256[] memory durations,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external returns(uint256[] memory IDs, IERC721 collection, uint256[] memory tokenIDs);

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
    ) external returns(uint256 ID, NFT memory token);
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
    ) external returns(uint256[] memory IDs, IERC721 collection, uint256[] memory tokenIDs);

    function buyTickets(uint256 ID, uint256 amount) external payable returns(uint256 tokensSpent);
    function buyTicketsWithSwap(uint256 ID, bytes calldata swapData) external payable returns(uint256 tokensSpent, uint256 ticketsBought);

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
    ) external returns (uint256 ID, IERC721 collection);
    function mintDrop(uint256 ID, uint256 quantity, bytes32[] memory merkleProof) external returns(uint256 mintPrice);

    function batchReceiveItems(uint256[] memory IDs, address recipient) external returns(IERC721[] memory collections, uint256[] memory tokenIDs);
    function batchReceiveTokens(uint256[] memory IDs, address recipient) external returns(uint256 amount);

    function batchReclaimItems(uint256[] memory IDs, address recipient) external returns(IERC721[] memory collections, uint256[] memory tokenIDs);
    function batchReclaimTokens(uint256[] memory IDs, address recipient) external returns(uint256 amount, uint256 chainlinkFeeRefund);

    function chainlinkFee(uint256 ID, uint256 amount) external view returns(uint256);
    function getListingsLength() external view returns(uint256 length);
    function getListingTicketIDBuyer(uint256 ID, uint256 ticket) external view returns(address);
    function getListingTicketsBoughtByAddress(uint256 ID, address _address) external view returns(uint256);

    function changeMinDuration(uint256 _minDuration) external;
    function changeMaxDuration(uint256 _maxDuration) external;
    function changeMaxTicketsBoughtByAddress(uint256 _maxTicketsBoughtByAddress) external;
    function changeFee(uint256 _fee) external;
    function changeChainlinkFeeShare(uint256 _chainlinkFeeShare) external;

    function fund(uint256 amount, uint256 amountETH) external returns (uint256);
}