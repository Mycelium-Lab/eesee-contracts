# Solidity API

## IEesee

### NFT

```solidity
struct NFT {
  contract IERC721 token;
  uint256 tokenID;
}
```

### Listing

```solidity
struct Listing {
  uint256 ID;
  struct IEesee.NFT nft;
  address owner;
  uint256 maxTickets;
  mapping(uint256 => address) ticketIDBuyer;
  mapping(address => uint256) ticketsBoughtByAddress;
  uint256 ticketPrice;
  uint256 ticketsBought;
  uint256 devFee;
  uint256 poolFee;
  uint256 creationTime;
  uint256 duration;
  address winner;
  bool chainlinkRequestSent;
  bool itemClaimed;
  bool tokensClaimed;
}
```

### ListItem

```solidity
event ListItem(uint256 ID, struct IEesee.NFT nft, address owner, uint256 maxTickets, uint256 ticketPrice, uint256 duration)
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
event FulfillListing(uint256 ID, struct IEesee.NFT nft, address winner)
```

### ReceiveItem

```solidity
event ReceiveItem(uint256 ID, struct IEesee.NFT nft, address recipient)
```

### ReceiveTokens

```solidity
event ReceiveTokens(uint256 ID, address recipient, uint256 amount)
```

### ReclaimItem

```solidity
event ReclaimItem(uint256 ID, struct IEesee.NFT nft, address recipient)
```

### ReclaimTokens

```solidity
event ReclaimTokens(uint256 ID, address sender, address recipient, uint256 tickets, uint256 amount)
```

### CollectDevFee

```solidity
event CollectDevFee(address to, uint256 amount)
```

### CollectPoolFee

```solidity
event CollectPoolFee(address pool, uint256 amount)
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

### ChangeMintFee

```solidity
event ChangeMintFee(uint256 previousMintFee, uint256 newMintFee)
```

### ChangeDevFee

```solidity
event ChangeDevFee(uint256 previousDevFee, uint256 newDevFee)
```

### ChangePoolFee

```solidity
event ChangePoolFee(uint256 previousPoolFee, uint256 newPoolFee)
```

### ChangeFeeCollector

```solidity
event ChangeFeeCollector(address previousFeeColector, address newFeeCollector)
```

### listings

```solidity
function listings(uint256) external view returns (uint256 ID, struct IEesee.NFT nft, address owner, uint256 maxTickets, uint256 ticketPrice, uint256 ticketsBought, uint256 devFee, uint256 poolFee, uint256 creationTime, uint256 duration, address winner, bool chainlinkRequestSent, bool itemClaimed, bool tokensClaime)
```

### ESE

```solidity
function ESE() external view returns (contract IERC20)
```

### rewardPool

```solidity
function rewardPool() external view returns (address)
```

### publicMinter

```solidity
function publicMinter() external view returns (contract eeseeNFT)
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

### mintFee

```solidity
function mintFee() external view returns (uint256)
```

### devFee

```solidity
function devFee() external view returns (uint256)
```

### poolFee

```solidity
function poolFee() external view returns (uint256)
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
function listItem(struct IEesee.NFT nft, uint256 maxTickets, uint256 ticketPrice, uint256 duration) external returns (uint256 ID)
```

### mintAndListItems

```solidity
function mintAndListItems(uint256[] maxTickets, uint256[] ticketPrices, uint256[] durations) external returns (uint256[] IDs, uint256[] tokenIDs)
```

### mintAndListItemsWithDeploy

```solidity
function mintAndListItemsWithDeploy(string name, string symbol, string baseURI, uint256[] maxTickets, uint256[] ticketPrices, uint256[] durations) external returns (uint256[] IDs, uint256[] tokenIDs)
```

### buyTickets

```solidity
function buyTickets(uint256 ID, uint256 amount) external returns (uint256 tokensSpent)
```

### batchReceiveItems

```solidity
function batchReceiveItems(uint256[] IDs, address recipient) external returns (contract IERC721[] tokens, uint256[] tokenIDs)
```

### batchReceiveTokens

```solidity
function batchReceiveTokens(uint256[] IDs, address recipient) external returns (uint256 amount)
```

### batchReclaimItems

```solidity
function batchReclaimItems(uint256[] IDs, address recipient) external returns (contract IERC721[] tokens, uint256[] tokenIDs)
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

### changeMintFee

```solidity
function changeMintFee(uint256 _mintFee) external
```

### changeDevFee

```solidity
function changeDevFee(uint256 _devFee) external
```

### changePoolFee

```solidity
function changePoolFee(uint256 _poolFee) external
```

### changeFeeCollector

```solidity
function changeFeeCollector(address _feeCollector) external
```

### fund

```solidity
function fund(uint96 amount) external
```

## eesee

### listings

```solidity
struct IEesee.Listing[] listings
```

_An array of all existing listings._

### ESE

```solidity
contract IERC20 ESE
```

_ESE token this contract uses._

### rewardPool

```solidity
address rewardPool
```

_Reward pool the fees are sent to._

### publicMinter

```solidity
contract eeseeNFT publicMinter
```

_Reward pool {poolFee} fees are sent to._

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

### mintFee

```solidity
uint256 mintFee
```

_Fixed fee that is collected if NFT is minted using this contract._

### devFee

```solidity
uint256 devFee
```

_Fee that is collected to {feeCollector} from each fulfilled listing. [1 ether == 100%]_

### poolFee

```solidity
uint256 poolFee
```

_Fee that is collected to {rewardPool} from each fulfilled listing. [1 ether == 100%]_

### feeCollector

```solidity
address feeCollector
```

_Address {devFee} fees are sent to._

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
constructor(contract IERC20 _ESE, address _rewardPool, string baseURI, address _feeCollector, address _vrfCoordinator, contract LinkTokenInterface _LINK, bytes32 _keyHash, uint16 _minimumRequestConfirmations, uint32 _callbackGasLimit) public
```

### listItem

```solidity
function listItem(struct IEesee.NFT nft, uint256 maxTickets, uint256 ticketPrice, uint256 duration) external returns (uint256 ID)
```

_Lists NFT from sender's balance. Emits {ListItem} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nft | struct IEesee.NFT | - NFT to list. Note: The sender must have it approved for this contract. |
| maxTickets | uint256 | - Max amount of tickets that can be bought by participants. |
| ticketPrice | uint256 | - Price for a single ticket. |
| duration | uint256 | - Duration of listings. Can be in range [minDuration, maxDuration]. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| ID | uint256 | - ID of listing created. |

### mintAndListItems

```solidity
function mintAndListItems(uint256[] maxTickets, uint256[] ticketPrices, uint256[] durations) external returns (uint256[] IDs, uint256[] tokenIDs)
```

_Mints NFTs to {publicMinter} collection and lists them. Emits {ListItem} event for each NFT listed._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| maxTickets | uint256[] | - Max amounts of tickets that can be bought by participants. |
| ticketPrices | uint256[] | - Prices for a single ticket. |
| durations | uint256[] | - Durations of listings. Can be in range [minDuration, maxDuration]. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| IDs | uint256[] | - IDs of listings created. |
| tokenIDs | uint256[] | - IDs of tokens that were minted. Note This function costs less than mintAndListItemsWithDeploy() but does not deploy additional NFT collection contract Note The sender must have {mintFee} of ESE approved. |

### mintAndListItemsWithDeploy

```solidity
function mintAndListItemsWithDeploy(string name, string symbol, string baseURI, uint256[] maxTickets, uint256[] ticketPrices, uint256[] durations) external returns (uint256[] IDs, uint256[] tokenIDs)
```

_Deploys new NFT collection contract, mints NFTs to it and lists them. Emits {ListItem} event for each NFT listed._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| name | string | - Name for a collection. |
| symbol | string | - Collection symbol. |
| baseURI | string | - URI to store NFT metadata in. |
| maxTickets | uint256[] | - Max amounts of tickets that can be bought by participants. |
| ticketPrices | uint256[] | - Prices for a single ticket. |
| durations | uint256[] | - Durations of listings. Can be in range [minDuration, maxDuration]. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| IDs | uint256[] | - IDs of listings created. |
| tokenIDs | uint256[] | - IDs of tokens that were minted. Note: This is more expensive than mintAndListItems() function but it deploys additional NFT contract. Note The sender must have {mintFee} of ESE approved. |

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

### batchReceiveItems

```solidity
function batchReceiveItems(uint256[] IDs, address recipient) external returns (contract IERC721[] tokens, uint256[] tokenIDs)
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
| tokens | contract IERC721[] | - Addresses of tokens received. |
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
function batchReclaimItems(uint256[] IDs, address recipient) external returns (contract IERC721[] tokens, uint256[] tokenIDs)
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
| tokens | contract IERC721[] | - Addresses of tokens reclaimed. |
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
function _listItem(struct IEesee.NFT nft, uint256 maxTickets, uint256 ticketPrice, uint256 duration) internal returns (uint256 ID)
```

### _collectMintFee

```solidity
function _collectMintFee() internal
```

### _collectSellFees

```solidity
function _collectSellFees(uint256 amount, uint256 _devFee, uint256 _poolFee) internal returns (uint256 feeAmount)
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

### changeMintFee

```solidity
function changeMintFee(uint256 _mintFee) external
```

_Changes mintFee. Emits {ChangeMintFee} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _mintFee | uint256 | - New mintFee. Note: This function can only be called by owner. |

### changeDevFee

```solidity
function changeDevFee(uint256 _devFee) external
```

_Changes devFee. Emits {ChangeDevFee} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _devFee | uint256 | - New devFee. Note: This function can only be called by owner. |

### changePoolFee

```solidity
function changePoolFee(uint256 _poolFee) external
```

_Changes poolFee. Emits {ChangePoolFee} event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _poolFee | uint256 | - New poolFee. Note: This function can only be called by owner. |

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

## eeseeNFT

### URI

```solidity
string URI
```

### constructor

```solidity
constructor(string name, string symbol, string _URI) public
```

### mint

```solidity
function mint(uint256 quantity) external
```

### startTokenId

```solidity
function startTokenId() external pure returns (uint256)
```

### _startTokenId

```solidity
function _startTokenId() internal pure returns (uint256)
```

_Returns the starting token ID.
To change the starting token ID, please override this function._

### nextTokenId

```solidity
function nextTokenId() external view returns (uint256)
```

### _baseURI

```solidity
function _baseURI() internal view returns (string)
```

_Base URI for computing {tokenURI}. If set, the resulting URI for each
token will be the concatenation of the `baseURI` and the `tokenId`. Empty
by default, it can be overridden in child contracts._

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

## ESE

### constructor

```solidity
constructor(uint256 amount) public
```

