// Because of the contract size limit we need a sepparate contract to mint NFTs.
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./eeseeNFT.sol";

contract eeseeMinter {
    ///@dev The collection contract NFTs are minted to to save gas.
    eeseeNFT public publicCollection;

    constructor(string memory baseURI, string memory contractURI) {
        publicCollection = new eeseeNFT("ESE Public Collection", "ESE-Public", baseURI, contractURI);
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
    function mintToPublicCollection(uint256 amount, string[] memory tokenURIs, address royaltyReceiver, uint96 royaltyFeeNumerator) external returns(address collection, uint256[] memory tokenIDs){
        require(tokenURIs.length == amount, "eesee: tokenURIs must have a length of amount");
        uint256 startTokenId = publicCollection.nextTokenId();
        publicCollection.mint(msg.sender, amount);

        tokenIDs = new uint256[](amount);
        for(uint256 i; i < amount; i++){
            tokenIDs[i] = i + startTokenId;
            publicCollection.setURIForTokenId(tokenIDs[i], tokenURIs[i]);
            publicCollection.setRoyaltyForTokenId(tokenIDs[i], royaltyReceiver, royaltyFeeNumerator);
        }
        collection = address(publicCollection);
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
    ) external returns(address collection, uint256[] memory tokenIDs){
        eeseeNFT privateCollection = new eeseeNFT(name, symbol, baseURI, contractURI);
        privateCollection.setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);

        uint256 startTokenId = privateCollection.nextTokenId();
        privateCollection.mint(msg.sender, amount);
        privateCollection.renounceOwnership();

        tokenIDs = new uint256[](amount);
        for(uint256 i; i < amount; i++){
            tokenIDs[i] = i + startTokenId;
        }
        collection = address(privateCollection);
    }
}
