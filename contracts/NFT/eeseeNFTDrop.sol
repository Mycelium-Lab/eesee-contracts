//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "operator-filter-registry/src/DefaultOperatorFilterer.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../interfaces/Ieesee.sol";
contract eeseeNFTDrop is ERC721A, ERC2981, Ownable, DefaultOperatorFilterer {
    mapping(uint256 => bytes32) private tokenURIHashes;
    mapping(uint256 => string) private tokenURIs;
    ///@dev baseURI this contract uses,
    string public URI;
    ///@dev Opensea royalty and NFT collection info
    string public contractURI;
    ///@dev 90% of mint fee is sent to this address
    address public earningsCollector;
    ///@dev Main eesee contract
    Ieesee public eesee;
    ///@dev Eesee fee amount
    uint256 public eeseeFeeAmount = 0.1 ether;
    ///@dev Mint cap
    uint256 public mintLimit;
    ///@dev Current amount of minted nfts
    uint256 public mintedAmount;
    ///@dev Info about sale stages
    SaleStage[] public stages;
    /**
     * @dev SaleStage:
     * {startTimestamp} - Timestamp when this stage starts.
     * {endTimestamp} - Timestamp when this stage ends.
     * {addressMintedAmount} - Amount of nfts minted by address.
     * {stageOptions} - Additional options for this stage.
     */
    struct SaleStage {
        uint256 startTimestamp;
        uint256 endTimestamp;
        mapping(address => uint256) addressMintedAmount;
        StageOptions stageOptions;
    }
    /**
     * @dev StageOptions:
     * {name} - Name of a mint stage.
     * {mintFee} - Price to mint 1 nft.
     * {duration} - Duration of mint stage.
     * {perAddressMintLimit} - Mint limit for one address.
     * {allowListMerkleRoot} - Root of merkle tree for allowlist.
     */
    struct StageOptions {     
        string name;
        uint256 mintFee;
        uint256 duration;
        uint256 perAddressMintLimit;
        bytes32 allowListMerkleRoot;
    }
    constructor(
        string memory name,
        string memory symbol,
        string memory _URI, 
        string memory _contractURI,
        RoyaltyInfo memory royaltyInfo,
        uint256 _mintLimit,
        address _earningsCollector,
        address _eeseeAddress,
        uint256 mintStartTimestamp,
        StageOptions memory publicStageOptions,
        StageOptions[] memory presalesOptions 
    ) ERC721A(name, symbol) {
        URI = _URI;
        eesee = Ieesee(_eeseeAddress);
        mintLimit = _mintLimit;
        contractURI = _contractURI;
        earningsCollector = _earningsCollector;
        _setDefaultRoyalty(royaltyInfo.receiver, royaltyInfo.royaltyFraction);
        setMintStageOptions(mintStartTimestamp, publicStageOptions, presalesOptions);
    }
    event MintOptionsChanged(uint256 mintStartTimestamp, StageOptions publicStageOptions, StageOptions[] presaleStagesOptions);
    event MintLimitChanged(uint256 newMintLimit);
    event EarningsCollectorChanged(address newEarningsCollector);
    // ============ View Functions ============
    /**
     * @dev Verifies that a user is in allowlist of saleStageIndex sale stage
     * @param saleStageIndex - Index of the sale stage
     * @param claimer - Address of a user
     * @param merkleProof - Merkle proof of stage's merkle tree
     
     * @return Returns true if user in stage's allowlist
     */
    function verifyCanMint (uint8 saleStageIndex, address claimer, bytes32[] memory merkleProof) public view returns (bool) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(claimer))));
        return MerkleProof.verify(merkleProof, stages[saleStageIndex].stageOptions.allowListMerkleRoot, leaf);
    }
    /**
     * @dev Returns current sale stages index
     
     * @return index - Index of current sale stage
     */
    function getSaleStage() public view returns (uint8 index) {
        for(uint8 i = 0; i < stages.length; i ++) {
            if (block.timestamp >= stages[i].startTimestamp && (block.timestamp <= stages[i].endTimestamp || stages[i].endTimestamp == 0)) {
                return i;
            }
        }
        return 0;
    }
    // ============ Write Functions ============
    /**
     * @dev Mints nfts for transaction sender
     * @param amount - Amount of nfts to mint
     * @param merkleProof - Merkle tree proof of transaction sender's address
     */
    function mint(uint256 amount, bytes32[] memory merkleProof) external payable {
        require(stages.length > 0, "eeseeNFTDrop: Admin hasn't configured sale settings for this contract yet.");
        require(block.timestamp >= stages[0].startTimestamp, "eeseeNFTDrop: Mint hasn't started yet.");
        require(block.timestamp <= stages[stages.length - 1].endTimestamp || stages[stages.length - 1].endTimestamp == 0, "eeseeNFTDrop: Mint has already ended.");
        uint8 saleStageIndex = getSaleStage();
        require(
            verifyCanMint(saleStageIndex, msg.sender, merkleProof) || 
            stages[saleStageIndex].stageOptions.allowListMerkleRoot == bytes32(0), 
            "eeseeNFTDrop: You are not in the allowlist of current sale stage.");
        require(
            amount + stages[saleStageIndex].addressMintedAmount[msg.sender] <= stages[saleStageIndex].stageOptions.perAddressMintLimit || 
            stages[saleStageIndex].stageOptions.perAddressMintLimit == 0, 
            "eeseeNFTDrop: You reached address mint limit."
            );
        require(
            msg.value >= stages[saleStageIndex].stageOptions.mintFee * amount || 
            stages[saleStageIndex].stageOptions.mintFee == 0 && msg.value == 0, 
            "eeseeNFTDrop: Insufficient funds for this amount."
            );
        require(
            mintLimit >= mintedAmount + amount ||
            mintLimit == 0, 
            "eeseeNFTDrop: You can't mint more than mint cap."
            );
        _safeMint(msg.sender, amount);
        stages[saleStageIndex].addressMintedAmount[msg.sender] += amount;
        mintedAmount += amount;
        if (stages[saleStageIndex].stageOptions.mintFee != 0) {
            uint256 mintPrice = stages[saleStageIndex].stageOptions.mintFee * amount;
            uint256 devFee = mintPrice * eeseeFeeAmount / 1 ether;
            address eeseeFeeCollector = eesee.feeCollector();
            (bool devFeeSent, ) = eeseeFeeCollector.call{value: devFee}("");
            require(devFeeSent, "eeseeNFTDrop: Error while sending fee to eesee fee collector.");
            (bool profitSent, ) = earningsCollector.call{value: mintPrice - devFee}("");
            require(profitSent, "eeseeNFTDrop: Error while sending fee to earnings address.");
            if (msg.value > stages[saleStageIndex].stageOptions.mintFee * amount) {
                (bool changeSent, ) = msg.sender.call{value: msg.value - mintPrice}("");
                require(changeSent, "eeseeNFTDrop: Error while sending excess eth.");
            }
        }
    }
    /**
     * @dev Sets options for mint stages
     * @param mintStartTimestamp - Mint start time
     * @param publicStageOptions - Options for public stage
     * @param presalesOptions - Options for presale stages 
     */
    function setMintStageOptions(uint256 mintStartTimestamp, StageOptions memory publicStageOptions, StageOptions[] memory presalesOptions) public onlyOwner{
        require(block.timestamp < mintStartTimestamp, "eeseeNFTDrop: Mint start timestamp must be in the future.");
        require(presalesOptions.length <= 5, "eeseeNFTDrop: Maximum amount of presale stages is 5.");
        require(stages.length == 0 || block.timestamp < stages[0].startTimestamp, "eeseeNFTDrop: Can't change mint settings if it has already started.");
        if(stages.length > 0 && block.timestamp < stages[0].startTimestamp) {
            delete stages;
        }
        uint256 timePassed = mintStartTimestamp;
        for(uint8 i = 0; i < presalesOptions.length; i ++) {
            require(presalesOptions[i].duration > 0, "eeseeNFTDrop: Duration of a sale stage can't be 0.");
            SaleStage storage presale = stages.push();
            presale.startTimestamp = timePassed;
            timePassed += presalesOptions[i].duration;
            presale.endTimestamp = timePassed;
            timePassed += 1;
            presale.stageOptions = presalesOptions[i];
        }
        SaleStage storage publicStage = stages.push();
        publicStage.stageOptions = publicStageOptions;
        publicStage.stageOptions.allowListMerkleRoot = bytes32(0);
        publicStage.startTimestamp = timePassed;
        if (publicStageOptions.duration != 0 ){
            publicStage.endTimestamp = publicStage.startTimestamp + publicStageOptions.duration;
        }
        emit MintOptionsChanged(mintStartTimestamp, publicStageOptions, presalesOptions);
    }
    /**
     * @dev Sets new mint limit cap
     * @param _mintLimit - New mint limit
     */
    function setMintLimit(uint256 _mintLimit) public onlyOwner {
        require(stages.length > 0 && block.timestamp < stages[0].startTimestamp || stages.length == 0, "eeseeNFTDrop: Mint has already started.");
        mintLimit = _mintLimit;
        emit MintLimitChanged(mintLimit);
    }
    /**
     * @dev Sets new earnings collector address
     * @param _earningsCollector - New earnings collector address
     */
    function setEarningsCollector (address _earningsCollector) public onlyOwner {
        require(stages.length > 0 && block.timestamp < stages[0].startTimestamp || stages.length == 0, "eeseeNFTDrop: Mint has already started.");
        earningsCollector = _earningsCollector;
        emit EarningsCollectorChanged(earningsCollector);
    }

    // ============ Internal Functions ============

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function _baseURI() internal view override returns (string memory) {
        return URI;
    }

    // ============ onlyAllowedOperatorApproval Overrides ============

    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId) payable public override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) payable public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) payable public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) payable public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    // ============ supportsInterface ============

    function supportsInterface(bytes4 interfaceId) public view override(ERC721A, ERC2981) returns (bool) {
        return ERC721A.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId);
    }
}
