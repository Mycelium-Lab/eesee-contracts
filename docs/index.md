# Solidity API

## eesee

### listings

```solidity
struct Ieesee.Listing[] listings
```

_An array of all existing listings._

### drops

```solidity
struct Ieesee.Drop[] drops
```

_An array of all existing drops listings._

### ESE

```solidity
contract IERC20 ESE
```

_ESE token this contract uses._

### minter

```solidity
contract IeeseeMinter minter
```

_Contract that mints NFTs_

### minDuration

```solidity
uint256 minDuration
```

_Min and max durations for a listing._

### maxDuration

```solidity
uint256 maxDuration
```

### maxTicketsBoughtByAddress

```solidity
uint256 maxTicketsBoughtByAddress
```

_Max tickets bought by a single address in a single listing. [1 ether == 100%]_

### fee

```solidity
uint256 fee
```

_Fee that is collected to {feeCollector} from each fulfilled listing. [1 ether == 100%]_

### feeCollector

```solidity
address feeCollector
```

_Address {fee}s are sent to._

### LINK

```solidity
contract LinkTokenInterface LINK
```

_Chainlink token._

### vrfCoordinator

```solidity
contract VRFCoordinatorV2Interface vrfCoordinator
```

_Chainlink VRF V2 coordinator._

### subscriptionID

```solidity
uint64 subscriptionID
```

_Chainlink VRF V2 subscription ID._

### keyHash

```solidity
bytes32 keyHash
```

_Chainlink VRF V2 key hash to call requestRandomWords() with._

### minimumRequestConfirmations

```solidity
uint16 minimumRequestConfirmations
```

_Chainlink VRF V2 request confirmations._

### constructor

```solidity
constructor(contract IERC20 _ESE, contract IeeseeMinter _minter, address _feeCollector, contract IRoyaltyEngineV1 _royaltyEngine, address _vrfCoordinator, contract LinkTokenInterface _LINK, bytes32 _keyHash, uint16 _minimumRequestConfirmations, uint32 _callbackGasLimit) public
```

### listItem

```solidity
function listItem(struct Ieesee.NFT nft, uint256 maxTickets, uint256 ticketPrice, uint256 duration) external returns (uint256 ID)
```

_Lists NFT from sender's balance. Emits {ListItem} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nft | struct Ieesee.NFT | - NFT to list. Note: The sender must have it approved for this contract. |
| maxTickets | uint256 | - Max amount of tickets that can be bought by participants. |
| ticketPrice | uint256 | - Price for a single ticket. |
| duration | uint256 | - Duration of listings. Can be in range [minDuration, maxDuration]. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| ID | uint256 | - ID of listing created. |

### listItems

```solidity
function listItems(struct Ieesee.NFT[] nfts, uint256[] maxTickets, uint256[] ticketPrices, uint256[] durations) external returns (uint256[] IDs)
```

_Lists NFTs from sender's balance. Emits {ListItem} events for each NFT listed._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nfts | struct Ieesee.NFT[] | - NFTs to list. Note: The sender must have them approved for this contract. |
| maxTickets | uint256[] | - Max amount of tickets that can be bought by participants. |
| ticketPrices | uint256[] | - Prices for a single ticket. |
| durations | uint256[] | - Durations of listings. Can be in range [minDuration, maxDuration]. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| IDs | uint256[] | - IDs of listings created. |

### mintAndListItem

```solidity
function mintAndListItem(string tokenURI, uint256 maxTickets, uint256 ticketPrice, uint256 duration, address royaltyReceiver, uint96 royaltyFeeNumerator) external returns (uint256 ID, contract IERC721 collection, uint256 tokenID)
```

_Mints NFT to a public collection and lists it. Emits {ListItem} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenURI | string | - Token metadata URI. |
| maxTickets | uint256 | - Max amounts of tickets that can be bought by participants. |
| ticketPrice | uint256 | - Price for a single ticket. |
| duration | uint256 | - Duration of listing. Can be in range [minDuration, maxDuration]. |
| royaltyReceiver | address | - Receiver of royalties from each NFT sale. |
| royaltyFeeNumerator | uint96 | - Amount of royalties to collect from each NFT sale. [10000 = 100%]. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| ID | uint256 | - ID of listing created. |
| collection | contract IERC721 | - Address of NFT collection contract. |
| tokenID | uint256 | - ID of token that was minted. Note This function costs less than mintAndListItemWithDeploy() but does not deploy additional NFT collection contract |

### mintAndListItems

```solidity
function mintAndListItems(string[] tokenURIs, uint256[] maxTickets, uint256[] ticketPrices, uint256[] durations, address royaltyReceiver, uint96 royaltyFeeNumerator) external returns (uint256[] IDs, contract IERC721 collection, uint256[] tokenIDs)
```

_Mints NFTs to a public collection and lists them. Emits {ListItem} event for each NFT listed._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenURIs | string[] | - Token metadata URIs. |
| maxTickets | uint256[] | - Max amounts of tickets that can be bought by participants. |
| ticketPrices | uint256[] | - Prices for a single ticket. |
| durations | uint256[] | - Durations of listings. Can be in range [minDuration, maxDuration]. |
| royaltyReceiver | address | - Receiver of royalties from each NFT sale. |
| royaltyFeeNumerator | uint96 | - Amount of royalties to collect from each NFT sale. [10000 = 100%]. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| IDs | uint256[] | - IDs of listings created. |
| collection | contract IERC721 | - Address of NFT collection contract. |
| tokenIDs | uint256[] | - IDs of tokens that were minted. Note This function costs less than mintAndListItemsWithDeploy() but does not deploy additional NFT collection contract |

### mintAndListItemWithDeploy

```solidity
function mintAndListItemWithDeploy(string name, string symbol, string baseURI, string contractURI, uint256 maxTickets, uint256 ticketPrice, uint256 duration, address royaltyReceiver, uint96 royaltyFeeNumerator) external returns (uint256 ID, contract IERC721 collection, uint256 tokenID)
```

_Deploys new NFT collection contract, mints NFT to it and lists it. Emits {ListItem} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| name | string | - Name for a collection. |
| symbol | string | - Collection symbol. |
| baseURI | string | - URI to store NFT metadata in. |
| contractURI | string |  |
| maxTickets | uint256 | - Max amounts of tickets that can be bought by participants. |
| ticketPrice | uint256 | - Price for a single ticket. |
| duration | uint256 | - Duration of listing. Can be in range [minDuration, maxDuration]. |
| royaltyReceiver | address | - Receiver of royalties from each NFT sale. |
| royaltyFeeNumerator | uint96 | - Amount of royalties to collect from each NFT sale. [10000 = 100%]. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| ID | uint256 | - ID of listings created. |
| collection | contract IERC721 | - Address of NFT collection contract. |
| tokenID | uint256 | - ID of tokens that were minted. Note: This is more expensive than mintAndListItem() function but it deploys additional NFT contract. |

### mintAndListItemsWithDeploy

```solidity
function mintAndListItemsWithDeploy(string name, string symbol, string baseURI, string contractURI, uint256[] maxTickets, uint256[] ticketPrices, uint256[] durations, address royaltyReceiver, uint96 royaltyFeeNumerator) external returns (uint256[] IDs, contract IERC721 collection, uint256[] tokenIDs)
```

_Deploys new NFT collection contract, mints NFTs to it and lists them. Emits {ListItem} event for each NFT listed._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| name | string | - Name for a collection. |
| symbol | string | - Collection symbol. |
| baseURI | string | - URI to store NFT metadata in. |
| contractURI | string |  |
| maxTickets | uint256[] | - Max amounts of tickets that can be bought by participants. |
| ticketPrices | uint256[] | - Prices for a single ticket. |
| durations | uint256[] | - Durations of listings. Can be in range [minDuration, maxDuration]. |
| royaltyReceiver | address | - Receiver of royalties from each NFT sale. |
| royaltyFeeNumerator | uint96 | - Amount of royalties to collect from each NFT sale. [10000 = 100%]. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| IDs | uint256[] | - IDs of listings created. |
| collection | contract IERC721 | - Address of NFT collection contract. |
| tokenIDs | uint256[] | - IDs of tokens that were minted. Note: This is more expensive than mintAndListItems() function but it deploys additional NFT contract. |

### buyTickets

```solidity
function buyTickets(uint256 ID, uint256 amount) external returns (uint256 tokensSpent)
```

_Buys tickets to participate in a draw. Requests Chainlink to generate random words if all tickets have been bought. Emits {BuyTicket} event for each ticket bought._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ID | uint256 | - ID of a listing to buy tickets for. |
| amount | uint256 | - Amount of tickets to buy. A single address can't buy more than {maxTicketsBoughtByAddress} of all tickets. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokensSpent | uint256 | - ESE tokens spent. |

### listDrop

```solidity
function listDrop(string name, string symbol, string URI, string contractURI, address royaltyReceiver, uint96 royaltyFeeNumerator, uint256 mintLimit, address earningsCollector, uint256 mintStartTimestamp, struct IeeseeNFTDrop.StageOptions publicStageOptions, struct IeeseeNFTDrop.StageOptions[] presalesOptions) external returns (uint256 ID, contract IERC721 collection)
```

_Deploys new NFT collection and lists it to users for minting. Emits {ListDrop} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| name | string | - Name for a collection. |
| symbol | string | - Collection symbol. |
| URI | string | - URI to store NFT metadata in. |
| contractURI | string | - URI to store collection metadata in. |
| royaltyReceiver | address | - Receiver of royalties from each NFT sale. |
| royaltyFeeNumerator | uint96 | - Amount of royalties to collect from each NFT sale. [10000 = 100%]. |
| mintLimit | uint256 | - Max amount of NFTs that can be minted. |
| earningsCollector | address | - Address to send NFT sale earnings to. |
| mintStartTimestamp | uint256 | - Timestamp when minting starts. |
| publicStageOptions | struct IeeseeNFTDrop.StageOptions | - Option for public stage. |
| presalesOptions | struct IeeseeNFTDrop.StageOptions[] | - Options for presales stages. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| ID | uint256 | - ID of a drop created. |
| collection | contract IERC721 | - Address of NFT collection contract. |

### mintDrop

```solidity
function mintDrop(uint256 ID, uint256 quantity, bytes32[] merkleProof) external returns (uint256 mintPrice)
```

_Mints NFTs from a drop. Emits {MintDrop} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ID | uint256 | - ID of a drop to mint NFTs from. |
| quantity | uint256 | - Amount of NFTs to mint. |
| merkleProof | bytes32[] | - Merkle proof for a user to mint NFTs. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| mintPrice | uint256 | - Amount of ESE tokens spent on minting. |

### batchReceiveItems

```solidity
function batchReceiveItems(uint256[] IDs, address recipient) external returns (contract IERC721[] collections, uint256[] tokenIDs)
```

_Receive NFTs the sender won from listings. Emits {ReceiveItem} event for each of the NFT received._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| IDs | uint256[] | - IDs of listings to claim NFTs in. |
| recipient | address | - Address to send NFTs to. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| collections | contract IERC721[] | - Addresses of tokens received. |
| tokenIDs | uint256[] | - IDs of tokens received. Note: Returning an array of NFT structs gives me "Stack too deep" error for some reason, so I have to return it this way |

### batchReceiveTokens

```solidity
function batchReceiveTokens(uint256[] IDs, address recipient) external returns (uint256 amount)
```

_Receive ESE the sender has earned from listings. Emits {ReceiveTokens} event for each of the claimed listing._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| IDs | uint256[] | - IDs of listings to claim tokens in. |
| recipient | address | - Address to send tokens to. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | - ESE received. |

### batchReclaimItems

```solidity
function batchReclaimItems(uint256[] IDs, address recipient) external returns (contract IERC721[] collections, uint256[] tokenIDs)
```

_Reclaim NFTs from expired listings. Emits {ReclaimItem} event for each listing ID._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| IDs | uint256[] | - IDs of listings to reclaim NFTs in. |
| recipient | address | - Address to send NFTs to. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| collections | contract IERC721[] | - Addresses of tokens reclaimed. |
| tokenIDs | uint256[] | - IDs of tokens reclaimed. Note: returning an array of NFT structs gives me "Stack too deep" error for some reason, so I have to return it this way |

### batchReclaimTokens

```solidity
function batchReclaimTokens(uint256[] IDs, address recipient) external returns (uint256 amount)
```

_Reclaim ESE from expired listings. Emits {ReclaimTokens} event for each listing ID._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| IDs | uint256[] | - IDs of listings to reclaim tokens in. |
| recipient | address | - Address to send tokens to. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | - ESE received. |

### getListingsLength

```solidity
function getListingsLength() external view returns (uint256 length)
```

_Get length of the listings array._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| length | uint256 | - Length of the listings array. |

### getDropsLength

```solidity
function getDropsLength() external view returns (uint256 length)
```

_Get length of the drops array._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| length | uint256 | - Length of the drops array. |

### getListingTicketIDBuyer

```solidity
function getListingTicketIDBuyer(uint256 ID, uint256 ticket) external view returns (address)
```

_Get the buyer of the specified ticket in listing._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ID | uint256 | - ID of the listing. |
| ticket | uint256 | - Ticket index. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | address - Ticket buyer. |

### getListingTicketsBoughtByAddress

```solidity
function getListingTicketsBoughtByAddress(uint256 ID, address _address) external view returns (uint256)
```

_Get the amount of tickets bought by address in listing._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| ID | uint256 | - ID of the listing. |
| _address | address | - Buyer address. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | uint256 - Tickets bought by {_address}. |

### _listItem

```solidity
function _listItem(struct Ieesee.NFT nft, uint256 maxTickets, uint256 ticketPrice, uint256 duration) internal returns (uint256 ID)
```

### _collectRoyalties

```solidity
function _collectRoyalties(uint256 value, struct Ieesee.NFT nft, address listingOwner) internal returns (uint256 royaltyAmount)
```

### _collectSellFees

```solidity
function _collectSellFees(uint256 amount, uint256 _fee) internal returns (uint256 feeAmount)
```

### fulfillRandomWords

```solidity
function fulfillRandomWords(uint256 requestID, uint256[] randomWords) internal
```

_This function is called by Chainlink. Chooses listing winner and emits {FulfillListing} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| requestID | uint256 | - Chainlink request ID. |
| randomWords | uint256[] | - Random values sent by Chainlink. |

### changeMinDuration

```solidity
function changeMinDuration(uint256 _minDuration) external
```

_Changes minDuration. Emits {ChangeMinDuration} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _minDuration | uint256 | - New minDuration. Note: This function can only be called by owner. |

### changeMaxDuration

```solidity
function changeMaxDuration(uint256 _maxDuration) external
```

_Changes maxDuration. Emits {ChangeMaxDuration} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _maxDuration | uint256 | - New maxDuration. Note: This function can only be called by owner. |

### changeMaxTicketsBoughtByAddress

```solidity
function changeMaxTicketsBoughtByAddress(uint256 _maxTicketsBoughtByAddress) external
```

_Changes maxTicketsBoughtByAddress. Emits {ChangeMaxTicketsBoughtByAddress} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _maxTicketsBoughtByAddress | uint256 | - New maxTicketsBoughtByAddress. Note: This function can only be called by owner. |

### changeFee

```solidity
function changeFee(uint256 _fee) external
```

_Changes fee. Emits {ChangeFee} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _fee | uint256 | - New fee. Note: This function can only be called by owner. |

### changeFeeCollector

```solidity
function changeFeeCollector(address _feeCollector) external
```

_Changes feeCollector. Emits {ChangeFeeCollector} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _feeCollector | address | - New feeCollector. Note: This function can only be called by owner. |

### fund

```solidity
function fund(uint96 amount) external
```

_Fund function for Chainlink's VRF V2 subscription._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint96 | - Amount of LINK to fund subscription with. |

## IRoyaltyEngineV1

_Lookup engine interface_

### getRoyalty

```solidity
function getRoyalty(address tokenAddress, uint256 tokenId, uint256 value) external returns (address payable[] recipients, uint256[] amounts)
```

Get the royalty for a given token (address, id) and value amount.  Does not cache the bps/amounts.  Caches the spec for a given token address

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenAddress | address | - The address of the token |
| tokenId | uint256 | - The id of the token |
| value | uint256 | - The value you wish to get the royalty of  returns Two arrays of equal length, royalty recipients and the corresponding amount each recipient should get |

### getRoyaltyView

```solidity
function getRoyaltyView(address tokenAddress, uint256 tokenId, uint256 value) external view returns (address payable[] recipients, uint256[] amounts)
```

View only version of getRoyalty

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenAddress | address | - The address of the token |
| tokenId | uint256 | - The id of the token |
| value | uint256 | - The value you wish to get the royalty of  returns Two arrays of equal length, royalty recipients and the corresponding amount each recipient should get |

## Ieesee

### NFT

```solidity
struct NFT {
  contract IERC721 collection;
  uint256 tokenID;
}
```

### Listing

```solidity
struct Listing {
  uint256 ID;
  struct Ieesee.NFT nft;
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
```

### Drop

```solidity
struct Drop {
  uint256 ID;
  contract IERC721 collection;
  address earningsCollector;
  uint256 fee;
}
```

### ListItem

```solidity
event ListItem(uint256 ID, struct Ieesee.NFT nft, address owner, uint256 maxTickets, uint256 ticketPrice, uint256 duration)
```

### BuyTicket

```solidity
event BuyTicket(uint256 ID, address buyer, uint256 ticketID, uint256 ticketPrice)
```

### RequestWords

```solidity
event RequestWords(uint256 ID, uint256 requestID)
```

### FulfillListing

```solidity
event FulfillListing(uint256 ID, struct Ieesee.NFT nft, address winner)
```

### ReceiveItem

```solidity
event ReceiveItem(uint256 ID, struct Ieesee.NFT nft, address recipient)
```

### ReceiveTokens

```solidity
event ReceiveTokens(uint256 ID, address recipient, uint256 amount)
```

### ReclaimItem

```solidity
event ReclaimItem(uint256 ID, struct Ieesee.NFT nft, address recipient)
```

### ReclaimTokens

```solidity
event ReclaimTokens(uint256 ID, address sender, address recipient, uint256 tickets, uint256 amount)
```

### CollectRoyalty

```solidity
event CollectRoyalty(address recipient, uint256 amount)
```

### CollectFee

```solidity
event CollectFee(address to, uint256 amount)
```

### ChangeMinDuration

```solidity
event ChangeMinDuration(uint256 previousMinDuration, uint256 newMinDuration)
```

### ChangeMaxDuration

```solidity
event ChangeMaxDuration(uint256 previousMaxDuration, uint256 newMaxDuration)
```

### ChangeMaxTicketsBoughtByAddress

```solidity
event ChangeMaxTicketsBoughtByAddress(uint256 previousMaxTicketsBoughtByAddress, uint256 newMaxTicketsBoughtByAddress)
```

### ChangeFee

```solidity
event ChangeFee(uint256 previousFee, uint256 newFee)
```

### ChangeFeeCollector

```solidity
event ChangeFeeCollector(address previousFeeColector, address newFeeCollector)
```

### ListDrop

```solidity
event ListDrop(uint256 ID, contract IERC721 collection, address earningsCollector)
```

### MintDrop

```solidity
event MintDrop(uint256 ID, struct Ieesee.NFT nft, address sender, uint256 mintFee)
```

### listings

```solidity
function listings(uint256) external view returns (uint256 ID, struct Ieesee.NFT nft, address owner, uint256 maxTickets, uint256 ticketPrice, uint256 ticketsBought, uint256 fee, uint256 creationTime, uint256 duration, address winner, bool itemClaimed, bool tokensClaimed)
```

### drops

```solidity
function drops(uint256) external view returns (uint256 ID, contract IERC721 collection, address earningsCollector, uint256 fee)
```

### ESE

```solidity
function ESE() external view returns (contract IERC20)
```

### minter

```solidity
function minter() external view returns (contract IeeseeMinter)
```

### minDuration

```solidity
function minDuration() external view returns (uint256)
```

### maxDuration

```solidity
function maxDuration() external view returns (uint256)
```

### maxTicketsBoughtByAddress

```solidity
function maxTicketsBoughtByAddress() external view returns (uint256)
```

### fee

```solidity
function fee() external view returns (uint256)
```

### feeCollector

```solidity
function feeCollector() external view returns (address)
```

### LINK

```solidity
function LINK() external view returns (contract LinkTokenInterface)
```

### vrfCoordinator

```solidity
function vrfCoordinator() external view returns (contract VRFCoordinatorV2Interface)
```

### subscriptionID

```solidity
function subscriptionID() external view returns (uint64)
```

### keyHash

```solidity
function keyHash() external view returns (bytes32)
```

### minimumRequestConfirmations

```solidity
function minimumRequestConfirmations() external view returns (uint16)
```

### listItem

```solidity
function listItem(struct Ieesee.NFT nft, uint256 maxTickets, uint256 ticketPrice, uint256 duration) external returns (uint256 ID)
```

### listItems

```solidity
function listItems(struct Ieesee.NFT[] nfts, uint256[] maxTickets, uint256[] ticketPrices, uint256[] durations) external returns (uint256[] IDs)
```

### mintAndListItem

```solidity
function mintAndListItem(string tokenURI, uint256 maxTickets, uint256 ticketPrice, uint256 duration, address royaltyReceiver, uint96 royaltyFeeNumerator) external returns (uint256 ID, contract IERC721 collection, uint256 tokenID)
```

### mintAndListItems

```solidity
function mintAndListItems(string[] tokenURIs, uint256[] maxTickets, uint256[] ticketPrices, uint256[] durations, address royaltyReceiver, uint96 royaltyFeeNumerator) external returns (uint256[] IDs, contract IERC721 collection, uint256[] tokenIDs)
```

### mintAndListItemWithDeploy

```solidity
function mintAndListItemWithDeploy(string name, string symbol, string baseURI, string contractURI, uint256 maxTickets, uint256 ticketPrice, uint256 duration, address royaltyReceiver, uint96 royaltyFeeNumerator) external returns (uint256 ID, contract IERC721 collection, uint256 tokenID)
```

### mintAndListItemsWithDeploy

```solidity
function mintAndListItemsWithDeploy(string name, string symbol, string baseURI, string contractURI, uint256[] maxTickets, uint256[] ticketPrices, uint256[] durations, address royaltyReceiver, uint96 royaltyFeeNumerator) external returns (uint256[] IDs, contract IERC721 collection, uint256[] tokenIDs)
```

### buyTickets

```solidity
function buyTickets(uint256 ID, uint256 amount) external returns (uint256 tokensSpent)
```

### listDrop

```solidity
function listDrop(string name, string symbol, string URI, string contractURI, address royaltyReceiver, uint96 royaltyFeeNumerator, uint256 mintLimit, address earningsCollector, uint256 mintStartTimestamp, struct IeeseeNFTDrop.StageOptions publicStageOptions, struct IeeseeNFTDrop.StageOptions[] presalesOptions) external returns (uint256 ID, contract IERC721 collection)
```

### mintDrop

```solidity
function mintDrop(uint256 ID, uint256 quantity, bytes32[] merkleProof) external returns (uint256 mintPrice)
```

### batchReceiveItems

```solidity
function batchReceiveItems(uint256[] IDs, address recipient) external returns (contract IERC721[] collections, uint256[] tokenIDs)
```

### batchReceiveTokens

```solidity
function batchReceiveTokens(uint256[] IDs, address recipient) external returns (uint256 amount)
```

### batchReclaimItems

```solidity
function batchReclaimItems(uint256[] IDs, address recipient) external returns (contract IERC721[] collections, uint256[] tokenIDs)
```

### batchReclaimTokens

```solidity
function batchReclaimTokens(uint256[] IDs, address recipient) external returns (uint256 amount)
```

### getListingsLength

```solidity
function getListingsLength() external view returns (uint256 length)
```

### getListingTicketIDBuyer

```solidity
function getListingTicketIDBuyer(uint256 ID, uint256 ticket) external view returns (address)
```

### getListingTicketsBoughtByAddress

```solidity
function getListingTicketsBoughtByAddress(uint256 ID, address _address) external view returns (uint256)
```

### changeMinDuration

```solidity
function changeMinDuration(uint256 _minDuration) external
```

### changeMaxDuration

```solidity
function changeMaxDuration(uint256 _maxDuration) external
```

### changeMaxTicketsBoughtByAddress

```solidity
function changeMaxTicketsBoughtByAddress(uint256 _maxTicketsBoughtByAddress) external
```

### changeFee

```solidity
function changeFee(uint256 _fee) external
```

### changeFeeCollector

```solidity
function changeFeeCollector(address _feeCollector) external
```

### fund

```solidity
function fund(uint96 amount) external
```

## IeeseeMinter

### publicCollection

```solidity
function publicCollection() external view returns (contract IERC721)
```

### mintToPublicCollection

```solidity
function mintToPublicCollection(uint256 amount, string[] tokenURIs, address royaltyReceiver, uint96 royaltyFeeNumerator) external returns (contract IERC721 collection, uint256[] tokenIDs)
```

### mintToPrivateCollection

```solidity
function mintToPrivateCollection(uint256 amount, string name, string symbol, string baseURI, string contractURI, address royaltyReceiver, uint96 royaltyFeeNumerator) external returns (contract IERC721 collection, uint256[] tokenIDs)
```

### deployDropCollection

```solidity
function deployDropCollection(string name, string symbol, string URI, string contractURI, address royaltyReceiver, uint96 royaltyFeeNumerator, uint256 mintLimit, uint256 mintStartTimestamp, struct IeeseeNFTDrop.StageOptions publicStageOptions, struct IeeseeNFTDrop.StageOptions[] presalesOptions) external returns (contract IERC721 collection)
```

## IeeseeNFTDrop

### SaleStage

```solidity
struct SaleStage {
  uint256 startTimestamp;
  uint256 endTimestamp;
  mapping(address => uint256) addressMintedAmount;
  struct IeeseeNFTDrop.StageOptions stageOptions;
}
```

### StageOptions

```solidity
struct StageOptions {
  string name;
  uint256 mintFee;
  uint256 duration;
  uint256 perAddressMintLimit;
  bytes32 allowListMerkleRoot;
}
```

### mint

```solidity
function mint(address recipient, uint256 quantity, bytes32[] merkleProof) external
```

### getSaleStage

```solidity
function getSaleStage() external view returns (uint8 index)
```

### stages

```solidity
function stages(uint256) external view returns (uint256 startTimestamp, uint256 endTimestamp, struct IeeseeNFTDrop.StageOptions stageOptions)
```

### nextTokenId

```solidity
function nextTokenId() external view returns (uint256)
```

## eeseeMinter

### publicCollection

```solidity
contract eeseeNFT publicCollection
```

_The collection contract NFTs are minted to to save gas._

### constructor

```solidity
constructor(string baseURI, string contractURI) public
```

### mintToPublicCollection

```solidity
function mintToPublicCollection(uint256 amount, string[] tokenURIs, address royaltyReceiver, uint96 royaltyFeeNumerator) external returns (address collection, uint256[] tokenIDs)
```

_Mints {amount} of NFTs to public collection to save gas._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | - Amount of NFTs to mint. |
| tokenURIs | string[] | - Metadata URIs of all NFTs minted. |
| royaltyReceiver | address | -  Receiver of royalties from each NFT sale. |
| royaltyFeeNumerator | uint96 | - Amount of royalties to collect from each NFT sale. [10000 = 100%]. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| collection | address | - Address of the collection the NFTs were minted to. |
| tokenIDs | uint256[] | - IDs of tokens minted. |

### mintToPrivateCollection

```solidity
function mintToPrivateCollection(uint256 amount, string name, string symbol, string baseURI, string contractURI, address royaltyReceiver, uint96 royaltyFeeNumerator) external returns (address collection, uint256[] tokenIDs)
```

_Deploys a sepparate private collection contract and mints {amount} of NFTs to it._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | - Amount of NFTs to mint. |
| name | string | - The name for a collection. |
| symbol | string | - The symbol of the collection. |
| baseURI | string | - Collection metadata URI. |
| contractURI | string | - Contract URI for opensea's royalties. |
| royaltyReceiver | address | - Receiver of royalties from each NFT sale. |
| royaltyFeeNumerator | uint96 | - Amount of royalties to collect from each NFT sale. [10000 = 100%]. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| collection | address | - Address of the collection the NFTs were minted to. |
| tokenIDs | uint256[] | - IDs of tokens minted. |

### deployDropCollection

```solidity
function deployDropCollection(string name, string symbol, string URI, string contractURI, address royaltyReceiver, uint96 royaltyFeeNumerator, uint256 mintLimit, uint256 mintStartTimestamp, struct IeeseeNFTDrop.StageOptions publicStageOptions, struct IeeseeNFTDrop.StageOptions[] presalesOptions) external returns (address collection)
```

_Deploys a new drop collection contract._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| name | string | - The name for a collection. |
| symbol | string | - The symbol of the collection. |
| URI | string | - Collection metadata URI. |
| contractURI | string | - Contract URI for opensea's royalties. |
| royaltyReceiver | address | - Receiver of royalties from each NFT sale. |
| royaltyFeeNumerator | uint96 | - Amount of royalties to collect from each NFT sale. [10000 = 100%]. |
| mintLimit | uint256 | - NFT mint cap |
| mintStartTimestamp | uint256 | - Mint start timestamp |
| publicStageOptions | struct IeeseeNFTDrop.StageOptions | - Option for the public NFT sale |
| presalesOptions | struct IeeseeNFTDrop.StageOptions[] | - Options for the NFT presales |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| collection | address | - Drops collection address |

## eeseeNFT

### URI

```solidity
string URI
```

_baseURI this contract uses,_

### contractURI

```solidity
string contractURI
```

_Opensea royalty and NFT collection info_

### SetURIForNonexistentToken

```solidity
error SetURIForNonexistentToken()
```

### SetRoyaltyForNonexistentToken

```solidity
error SetRoyaltyForNonexistentToken()
```

### constructor

```solidity
constructor(string name, string symbol, string _URI, string _contractURI) public
```

### tokenURI

```solidity
function tokenURI(uint256 tokenId) public view virtual returns (string)
```

_Returns tokenId's token URI. If there is no URI in tokenURIs uses baseURI._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | - Token ID to check. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | string | string Token URI. |

### nextTokenId

```solidity
function nextTokenId() external view returns (uint256)
```

_Returns next token ID to be minted._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | uint256 Token ID. |

### mint

```solidity
function mint(address recipient, uint256 quantity) external
```

_Mints a {quantity} of NFTs and sends them to the {recipient}._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| recipient | address | - Receiver of NFTs. |
| quantity | uint256 | - Quantity of NFTs to mint.       Note: This function can only be called by owner. |

### setURIForTokenId

```solidity
function setURIForTokenId(uint256 tokenId, string _tokenURI) external
```

_Sets {_tokenURI} for a specified {tokenId}._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | - Token ID to set URI for. |
| _tokenURI | string | - Token URI.       Note: This function can only be called by owner. |

### setDefaultRoyalty

```solidity
function setDefaultRoyalty(address receiver, uint96 feeNumerator) external
```

_Sets default royalty for this collection._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| receiver | address | - Royalty receiver. |
| feeNumerator | uint96 | - Royalty amount. [10000 == 100%].       Note: This function can only be called by owner. |

### setRoyaltyForTokenId

```solidity
function setRoyaltyForTokenId(uint256 tokenId, address receiver, uint96 feeNumerator) external
```

_Sets royalty for a single {tokenId} in the collection._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | - Token ID to set royalty for. |
| receiver | address | - Royalty receiver. |
| feeNumerator | uint96 | - Royalty amount. [10000 == 100%].       Note: This function can only be called by owner. |

### _startTokenId

```solidity
function _startTokenId() internal pure returns (uint256)
```

_Returns the starting token ID.
To change the starting token ID, please override this function._

### _baseURI

```solidity
function _baseURI() internal view returns (string)
```

_Base URI for computing {tokenURI}. If set, the resulting URI for each
token will be the concatenation of the `baseURI` and the `tokenId`. Empty
by default, it can be overridden in child contracts._

### setApprovalForAll

```solidity
function setApprovalForAll(address operator, bool approved) public
```

_Approve or remove `operator` as an operator for the caller.
Operators can call {transferFrom} or {safeTransferFrom}
for any token owned by the caller.

Requirements:

- The `operator` cannot be the caller.

Emits an {ApprovalForAll} event._

### approve

```solidity
function approve(address operator, uint256 tokenId) public payable
```

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 tokenId) public payable
```

_Transfers `tokenId` from `from` to `to`.

Requirements:

- `from` cannot be the zero address.
- `to` cannot be the zero address.
- `tokenId` token must be owned by `from`.
- If the caller is not `from`, it must be approved to move this token
by either {approve} or {setApprovalForAll}.

Emits a {Transfer} event._

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) public view returns (bool)
```

## eeseeNFTDrop

### URI

```solidity
string URI
```

_baseURI this contract uses,_

### contractURI

```solidity
string contractURI
```

_Opensea royalty and NFT collection info_

### mintLimit

```solidity
uint256 mintLimit
```

_Mint cap_

### mintedAmount

```solidity
uint256 mintedAmount
```

_Current amount of minted nfts_

### stages

```solidity
struct IeeseeNFTDrop.SaleStage[] stages
```

_Info about sale stages_

### MintTimestampNotInFuture

```solidity
error MintTimestampNotInFuture()
```

### PresaleStageLimitExceeded

```solidity
error PresaleStageLimitExceeded()
```

### ZeroSaleStageDuration

```solidity
error ZeroSaleStageDuration()
```

### MintLimitExceeded

```solidity
error MintLimitExceeded()
```

### MintingNotStarted

```solidity
error MintingNotStarted()
```

### MintingEnded

```solidity
error MintingEnded()
```

### NotInAllowlist

```solidity
error NotInAllowlist()
```

### constructor

```solidity
constructor(string name, string symbol, string _URI, string _contractURI, address royaltyReceiver, uint96 royaltyFeeNumerator, uint256 _mintLimit, uint256 mintStartTimestamp, struct IeeseeNFTDrop.StageOptions publicStageOptions, struct IeeseeNFTDrop.StageOptions[] presalesOptions) public
```

### verifyCanMint

```solidity
function verifyCanMint(uint8 saleStageIndex, address claimer, bytes32[] merkleProof) public view returns (bool)
```

_Verifies that a user is in allowlist of saleStageIndex sale stage._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| saleStageIndex | uint8 | - Index of the sale stage. |
| claimer | address | - Address of a user. |
| merkleProof | bytes32[] | - Merkle proof of stage's merkle tree. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool true if user in stage's allowlist. |

### getSaleStage

```solidity
function getSaleStage() public view returns (uint8 index)
```

_Returns current sale stages index._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| index | uint8 | - Index of current sale stage. |

### nextTokenId

```solidity
function nextTokenId() external view returns (uint256)
```

_Returns next token ID to be minted._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | uint256 Token ID. |

### mint

```solidity
function mint(address recipient, uint256 quantity, bytes32[] merkleProof) external
```

_Mints nfts for recipient in the merkle tree._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| recipient | address | - Address of recipient. |
| quantity | uint256 | - Amount of nfts to mint. |
| merkleProof | bytes32[] | - Merkle tree proof of transaction sender's address.  Note: This function can only be called by owner. |

### _startTokenId

```solidity
function _startTokenId() internal pure returns (uint256)
```

_Returns the starting token ID.
To change the starting token ID, please override this function._

### _baseURI

```solidity
function _baseURI() internal view returns (string)
```

_Base URI for computing {tokenURI}. If set, the resulting URI for each
token will be the concatenation of the `baseURI` and the `tokenId`. Empty
by default, it can be overridden in child contracts._

### _setMintStageOptions

```solidity
function _setMintStageOptions(uint256 mintStartTimestamp, struct IeeseeNFTDrop.StageOptions publicStageOptions, struct IeeseeNFTDrop.StageOptions[] presalesOptions) internal
```

### setApprovalForAll

```solidity
function setApprovalForAll(address operator, bool approved) public
```

_Approve or remove `operator` as an operator for the caller.
Operators can call {transferFrom} or {safeTransferFrom}
for any token owned by the caller.

Requirements:

- The `operator` cannot be the caller.

Emits an {ApprovalForAll} event._

### approve

```solidity
function approve(address operator, uint256 tokenId) public payable
```

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 tokenId) public payable
```

_Transfers `tokenId` from `from` to `to`.

Requirements:

- `from` cannot be the zero address.
- `to` cannot be the zero address.
- `tokenId` token must be owned by `from`.
- If the caller is not `from`, it must be approved to move this token
by either {approve} or {setApprovalForAll}.

Emits a {Transfer} event._

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) public view returns (bool)
```

## ESE

### constructor

```solidity
constructor(uint256 amount) public
```

## eeseePool

### Claim

```solidity
struct Claim {
  uint256 rewardID;
  uint256 balance;
  bytes32[] merkleProof;
}
```

### rewardToken

```solidity
contract IERC20 rewardToken
```

_ESE token this contract uses._

### rewardID

```solidity
uint256 rewardID
```

_Current reward ID._

### rewardRoot

```solidity
mapping(uint256 => bytes32) rewardRoot
```

_Maps {rewardID} to its merkle root._

### isClaimed

```solidity
mapping(address => mapping(uint256 => bool)) isClaimed
```

_Has address claimed reward for {rewardID}._

### RewardAdded

```solidity
event RewardAdded(uint256 rewardID, bytes32 merkleRoot)
```

### RewardClaimed

```solidity
event RewardClaimed(uint256 rewardID, address claimer, uint256 amount)
```

### constructor

```solidity
constructor(contract IERC20 _rewardToken) public
```

### claimRewards

```solidity
function claimRewards(struct eeseePool.Claim[] claims) external
```

_Claims rewards for multiple {rewardID}s. Emits {RewardClaimed} event for each reward claimed._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| claims | struct eeseePool.Claim[] | - Claim structs. |

### addReward

```solidity
function addReward(bytes32 merkleRoot) external
```

_Adds new merkle root and advances to the next {rewardID}. Emits {RewardAdded} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| merkleRoot | bytes32 | - Merkle root. |

### getRewards

```solidity
function getRewards(address claimer, struct eeseePool.Claim[] claims) external view returns (uint256 rewards)
```

_Verifies {claims} and returns rewards to be claimed from {claims}._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| claimer | address | - Address to check. |
| claims | struct eeseePool.Claim[] | - Claims to check. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| rewards | uint256 | - Rewards to be claimed. |

### verifyClaim

```solidity
function verifyClaim(address claimer, struct eeseePool.Claim claim) public view returns (bool)
```

_Verifies {claim} for {claimer}._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| claimer | address | - Address to verify claim for. |
| claim | struct eeseePool.Claim | - Claim to verify. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool - Does {claim} exist in merkle root. |

## MockRoyaltyEngine

### getRoyalty

```solidity
function getRoyalty(address tokenAddress, uint256 tokenId, uint256 value) public view returns (address payable[] recipients, uint256[] amounts)
```

## MockVRFCoordinator

### VRF

```solidity
struct VRF {
  contract VRFConsumerBaseV2 consumer;
  uint32 callbackGasLimit;
}
```

### counter

```solidity
uint256 counter
```

### vrf

```solidity
mapping(uint256 => struct MockVRFCoordinator.VRF) vrf
```

### requestRandomWords

```solidity
function requestRandomWords(bytes32, uint64, uint16, uint32 callbackGasLimit, uint32) external returns (uint256)
```

### fulfillWords

```solidity
function fulfillWords(uint256 requestId) external
```

### createSubscription

```solidity
function createSubscription() external returns (uint64 subscriptionID)
```

### addConsumer

```solidity
function addConsumer(uint64, address) external
```

