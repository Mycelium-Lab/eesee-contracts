//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../interfaces/IeeseeNFTDrop.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "operator-filter-registry/src/DefaultOperatorFilterer.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract eeseeNFTDrop is IeeseeNFTDrop, ERC721A, ERC2981, Ownable, DefaultOperatorFilterer {
    ///@dev baseURI this contract uses,
    string public URI;
    ///@dev Opensea royalty and NFT collection info
    string public contractURI;
    ///@dev Mint cap
    uint256 public mintLimit;
    ///@dev Current amount of minted nfts
    uint256 public mintedAmount;
    ///@dev Info about sale stages
    SaleStage[] public stages;

    error MintTimestampNotInFuture();
    error PresaleStageLimitExceeded();
    error ZeroSaleStageDuration();
    error MintLimitExceeded();
    error MintingNotStarted();
    error MintingEnded();
    error NotInAllowlist();

    constructor(
        string memory name,
        string memory symbol,
        string memory _URI, 
        string memory _contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        uint256 _mintLimit,
        uint256 mintStartTimestamp, 
        StageOptions memory publicStageOptions,
        StageOptions[] memory presalesOptions
    ) ERC721A(name, symbol) {
        URI = _URI;
        mintLimit = _mintLimit;
        contractURI = _contractURI;
        _setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);
        _setMintStageOptions(mintStartTimestamp, publicStageOptions, presalesOptions);
    }

    // ============ View Functions ============

    /**
     * @dev Verifies that a user is in allowlist of saleStageIndex sale stage.
     * @param saleStageIndex - Index of the sale stage.
     * @param claimer - Address of a user.
     * @param merkleProof - Merkle proof of stage's merkle tree.
     
     * @return bool true if user in stage's allowlist.
     */
    function verifyCanMint(uint8 saleStageIndex, address claimer, bytes32[] memory merkleProof) public view returns (bool) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(claimer))));
        return MerkleProof.verify(merkleProof, stages[saleStageIndex].stageOptions.allowListMerkleRoot, leaf);
    }

    /**
     * @dev Returns current sale stages index.
     
     * @return index - Index of current sale stage.
     */
    function getSaleStage() public view returns (uint8 index) {
        for(uint8 i = 0; i < stages.length; i ++) {
            if (block.timestamp >= stages[i].startTimestamp && (block.timestamp <= stages[i].endTimestamp || stages[i].endTimestamp == 0)) {
                return i;
            }
        }
        return 0;
    }

    /**
     * @dev Returns next token ID to be minted.
     
     * @return uint256 Token ID.
     */
    function nextTokenId() external view returns (uint256) {
        return _nextTokenId();
    }

    // ============ Write Functions ============

    /**
     * @dev Mints nfts for recipient in the merkle tree.
     * @param recipient - Address of recipient.
     * @param quantity - Amount of nfts to mint.
     * @param merkleProof - Merkle tree proof of transaction sender's address.

     * Note: This function can only be called by owner.
     */
    function mint(address recipient, uint256 quantity, bytes32[] memory merkleProof) external onlyOwner {
        if(block.timestamp < stages[0].startTimestamp){
            revert MintingNotStarted();
        }
        if(block.timestamp > stages[stages.length - 1].endTimestamp && stages[stages.length - 1].endTimestamp != 0){
            revert MintingEnded();
        }
        uint8 saleStageIndex = getSaleStage();

        if(!verifyCanMint(saleStageIndex, recipient, merkleProof) && stages[saleStageIndex].stageOptions.allowListMerkleRoot != bytes32(0)){
            revert NotInAllowlist();
        }
        if(quantity + stages[saleStageIndex].addressMintedAmount[recipient] > stages[saleStageIndex].stageOptions.perAddressMintLimit && stages[saleStageIndex].stageOptions.perAddressMintLimit != 0){
            revert MintLimitExceeded();
        }
        if(mintedAmount + quantity > mintLimit && mintLimit != 0){
            revert MintLimitExceeded();
        }

        _safeMint(recipient, quantity);
        stages[saleStageIndex].addressMintedAmount[recipient] += quantity;
        mintedAmount += quantity;
    }

    // ============ Internal Functions ============

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function _baseURI() internal view override returns (string memory) {
        return URI;
    }

    function _setMintStageOptions(uint256 mintStartTimestamp, StageOptions memory publicStageOptions, StageOptions[] memory presalesOptions) internal {
        if(block.timestamp >= mintStartTimestamp){
            revert MintTimestampNotInFuture();
        }
        if(presalesOptions.length > 5){
            revert PresaleStageLimitExceeded();
        }

        uint256 timePassed = mintStartTimestamp;
        for(uint8 i = 0; i < presalesOptions.length; i ++) {
            if(presalesOptions[i].duration == 0){
                revert ZeroSaleStageDuration();
            }
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

    // ============ supportsInterface ============

    function supportsInterface(bytes4 interfaceId) public view override(ERC721A, ERC2981) returns (bool) {
        return ERC721A.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId);
    }
}
