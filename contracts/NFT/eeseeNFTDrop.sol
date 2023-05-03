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
    address public earningsCollector;
    address public eeseeFeeCollector;
    uint256 public eeseeFeeAmount = 0.1 ether;
    uint256 public mintLimit;
    uint256 public mintedAmount;
    SaleStage[] public stages;
    struct SaleStage {
        uint256 startTimestamp;
        uint256 endTimestamp;
        mapping(address => uint256) addressMintedAmount;
        StageOptions stageOptions;
    }
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
        string memory _URI, // URI for unrevealed NFTs
        string memory _contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        uint256 _mintLimit,
        address _earningsCollector,
        address _eeseeAddress
    ) ERC721A(name, symbol) {
        URI = _URI;
        Ieesee eesee = Ieesee(_eeseeAddress);
        eeseeFeeCollector = eesee.feeCollector();
        mintLimit = _mintLimit;
        contractURI = _contractURI;
        earningsCollector = _earningsCollector;
        _setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);
    }
    event MintOptionsChanged(uint256 mintStartTimestamp, StageOptions publicStageOptions, StageOptions[] presaleStagesOptions);

    // ============ View Functions ============

    /**
     * @dev Returns tokenId's token URI. If there is no URI in tokenURIs uses baseURI.
     * @param tokenId - Token ID to check.
     
     * @return string Token URI.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();
        bytes memory str = bytes(tokenURIs[tokenId]);
        if(str.length == 0){
            string memory baseURI = _baseURI();
            return bytes(baseURI).length != 0 ? baseURI : '';
        }
        return tokenURIs[tokenId];
    }
    function verifyCanMint (uint8 saleIndex, address claimer, bytes32[] memory merkleProof) public view returns (bool) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(claimer))));
        return MerkleProof.verify(merkleProof, stages[saleIndex].stageOptions.allowListMerkleRoot, leaf);
    }
    function getSaleStage() public view returns (uint8 index) {
        for(uint8 i = 0; i < stages.length; i ++) {
            if (block.timestamp >= stages[i].startTimestamp && (block.timestamp <= stages[i].endTimestamp || stages[i].endTimestamp == 0)) {
                return i;
            }
        }
        return 0;
    }
    // ============ Write Functions ============

    function mint(uint256 amount, bytes32[] memory merkleProof) external payable {
        require(stages.length > 0, "eeseeNFTDrop: Admin hasn't configured sale settings for this contract yet.");
        require(block.timestamp >= stages[0].startTimestamp, "eeseeNFTDrop: Mint hasn't started yet.");
        require(block.timestamp <= stages[stages.length - 1].endTimestamp || stages[stages.length - 1].endTimestamp == 0, "eeseeNFTDrop: Mint has already ended.");
        uint8 saleIndex = getSaleStage();
        require(
            verifyCanMint(saleIndex, msg.sender, merkleProof) || 
            stages[saleIndex].stageOptions.allowListMerkleRoot.length == 0, 
            "eeseeNFTDrop: You are not in the allowlist of current sale stage.");
        require(
            amount + stages[saleIndex].addressMintedAmount[msg.sender] <= stages[saleIndex].stageOptions.perAddressMintLimit || 
            stages[saleIndex].stageOptions.perAddressMintLimit == 0, 
            "eeseeNFTDrop: You reached address mint limit."
            );
        require(
            msg.value >= stages[saleIndex].stageOptions.mintFee * amount || 
            stages[saleIndex].stageOptions.mintFee == 0 && msg.value == 0, 
            "eeseeNFTDrop: Insufficient funds for this amount."
            );
        require(
            mintLimit <= mintedAmount + amount ||
            mintLimit == 0, 
            "eeseeNFTDrop: You can't mint more than mint cap."
            );
        _safeMint(msg.sender, amount);
        stages[saleIndex].addressMintedAmount[msg.sender] += amount;
        mintedAmount += amount;
        if (stages[saleIndex].stageOptions.mintFee != 0) {
            uint256 devFee = stages[saleIndex].stageOptions.mintFee * amount * eeseeFeeAmount / 1 ether;
            (bool devFeeSent, ) = eeseeFeeCollector.call{value: devFee}("");
            require(devFeeSent, "eeseeNFTDrop: Error while sending fee to eesee fee collector.");
            (bool profitSent, ) = earningsCollector.call{value: stages[saleIndex].stageOptions.mintFee * amount - devFee}("");
            require(profitSent, "eeseeNFTDrop: Error while sending fee to earnings address.");
            if (msg.value > stages[saleIndex].stageOptions.mintFee * amount) {
                (bool changeSent, ) = msg.sender.call{value: msg.value - stages[saleIndex].stageOptions.mintFee * amount}("");
                require(changeSent, "eeseeNFTDrop: Error while sending excess eth.");
            }
        }
    }
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

    function setMintLimit(uint256 _mintLimit) public onlyOwner {
        require(stages.length > 0 && block.timestamp < stages[0].startTimestamp || stages.length == 0, "eeseeNFTDrop: Mint has already started.");
        mintLimit = _mintLimit;
    }

    function setEarningsCollector (address _earningsCollector) public onlyOwner {
         require(stages.length > 0 && block.timestamp < stages[0].startTimestamp || stages.length == 0, "eeseeNFTDrop: Mint has already started.");
        earningsCollector = _earningsCollector;
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
