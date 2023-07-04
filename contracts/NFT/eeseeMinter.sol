// Because of the contract size limit we need a sepparate contract to mint NFTs.
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./eeseeNFT.sol";
import "./eeseeNFTDrop.sol";
import "../interfaces/IeeseeMinter.sol";

contract eeseeMinter is IeeseeMinter {
    ///@dev The collection contract NFTs are minted to to save gas.
    IeeseeNFT public immutable publicCollection;

    constructor(string memory baseURI, string memory contractURI) {
        publicCollection = IeeseeNFT(new eeseeNFT("ESE Public Collection", "ESE-Public", baseURI, contractURI));
    }

    /**
     * @dev Mints {amount} of NFTs to public collection to save gas.
     * @param amount - Amount of NFTs to mint.
     * @param tokenURIs - Metadata URIs of all NFTs minted.
     * @param royaltyReceiver -  Receiver of royalties from each NFT sale.
     * @param royaltyFeeNumerator - Amount of royalties to collect from each NFT sale. [10000 = 100%].
     
     * @return collection - Address of the collection the NFTs were minted to.
     * @return tokenIDs - IDs of tokens minted.
     */
    function mintToPublicCollection(uint256 amount, string[] memory tokenURIs, address royaltyReceiver, uint96 royaltyFeeNumerator) external returns(IERC721 collection, uint256[] memory tokenIDs){
        if(tokenURIs.length != amount) revert IncorrectTokenURILength();
        uint256 startTokenId = publicCollection.nextTokenId();
        publicCollection.mint(msg.sender, amount);

        tokenIDs = new uint256[](amount);
        for(uint256 i; i < amount;){
            tokenIDs[i] = i + startTokenId;
            publicCollection.setURIForTokenId(tokenIDs[i], tokenURIs[i]);
            publicCollection.setRoyaltyForTokenId(tokenIDs[i], royaltyReceiver, royaltyFeeNumerator);
            unchecked{ i++; }
        }
        collection = IERC721(address(publicCollection));
    }

    /**
     * @dev Deploys a sepparate private collection contract and mints {amount} of NFTs to it.
     * @param amount - Amount of NFTs to mint.
     * @param name - The name for a collection.
     * @param symbol - The symbol of the collection.
     * @param baseURI - Collection metadata URI.
     * @param contractURI - Contract URI for opensea's royalties.
     * @param royaltyReceiver - Receiver of royalties from each NFT sale.
     * @param royaltyFeeNumerator - Amount of royalties to collect from each NFT sale. [10000 = 100%].
     
     * @return collection - Address of the collection the NFTs were minted to.
     * @return tokenIDs - IDs of tokens minted.
     */
    function mintToPrivateCollection(
        uint256 amount,
        string memory name, 
        string memory symbol, 
        string memory baseURI, 
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external returns(IERC721 collection, uint256[] memory tokenIDs){
        eeseeNFT privateCollection = new eeseeNFT(name, symbol, baseURI, contractURI);
        privateCollection.setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);

        uint256 startTokenId = privateCollection.nextTokenId();
        privateCollection.mint(msg.sender, amount);
        privateCollection.renounceOwnership();

        tokenIDs = new uint256[](amount);
        for(uint256 i; i < amount;){
            tokenIDs[i] = i + startTokenId;
            unchecked{ i++; }
        }
        collection = IERC721(address(privateCollection));
    }

    /**
     * @dev Deploys a new drop collection contract.
     * @param name - The name for a collection.
     * @param symbol - The symbol of the collection.
     * @param URI - Collection metadata URI.
     * @param contractURI - Contract URI for opensea's royalties.
     * @param royaltyReceiver - Receiver of royalties from each NFT sale.
     * @param royaltyFeeNumerator - Amount of royalties to collect from each NFT sale. [10000 = 100%].
     * @param mintLimit - NFT mint cap
     * @param mintStartTimestamp - Mint start timestamp
     * @param publicStageOptions - Option for the public NFT sale
     * @param presalesOptions - Options for the NFT presales 

     * @return collection - Drops collection address
     */
    function deployDropCollection(
        string memory name, 
        string memory symbol, 
        string memory URI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        uint256 mintLimit,
        uint256 mintStartTimestamp, 
        IeeseeNFTDrop.StageOptions memory publicStageOptions,
        IeeseeNFTDrop.StageOptions[] memory presalesOptions
    ) external returns(IERC721 collection){
        eeseeNFTDrop dropCollection = new eeseeNFTDrop(
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
        dropCollection.transferOwnership(msg.sender);
        collection = IERC721(address(dropCollection));
    }
}
