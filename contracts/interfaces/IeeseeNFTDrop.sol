// Because of the contract size limit we need a sepparate contract to mint NFTs.
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IeeseeNFTDrop {
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

    error MintTimestampNotInFuture();
    error PresaleStageLimitExceeded();
    error ZeroSaleStageDuration();
    error MintLimitExceeded();
    error MintingNotStarted();
    error MintingEnded();
    error NotInAllowlist();

    function URI() external view returns (string memory);
    function contractURI() external view returns (string memory);
    function mintLimit() external view returns (uint256);
    function mintedAmount() external view returns (uint256);

    function getSaleStage() external view returns (uint8 index);
    function stages(uint256) external view returns (uint256 startTimestamp, uint256 endTimestamp, StageOptions memory stageOptions);
    
    function nextTokenId() external view returns (uint256);
    function verifyCanMint(uint8 saleStageIndex, address claimer, bytes32[] memory merkleProof) external view returns (bool);

    function mint(address recipient, uint256 quantity, bytes32[] memory merkleProof) external;
}
