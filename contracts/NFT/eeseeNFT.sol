//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "operator-filter-registry/src/DefaultOperatorFilterer.sol";

contract eeseeNFT is ERC721A, ERC2981, Ownable, DefaultOperatorFilterer {
    ///@dev tokenId => tokenURI.
    mapping(uint256 => string) private tokenURIs;
    ///@dev baseURI this contract uses,
    string public URI;
    ///@dev Opensea royalty and NFT collection info
    string public contractURI;
    
    constructor(
        string memory name,
        string memory symbol,
        string memory _URI,
        string memory _contractURI
    ) ERC721A(name, symbol) {
        URI = _URI;
        contractURI = _contractURI;
    }

    /**
     * @dev Returns tokenId's token URI. If there is no URI in tokenURIs uses baseURI.
     * @param tokenId - Token ID to check.
     
     * @return string Token URI.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        bytes memory str = bytes(tokenURIs[tokenId]);
        if(str.length == 0){
            return super.tokenURI(tokenId);
        }
        return tokenURIs[tokenId];
    }

    /**
     * @dev Returns next token ID to be minted.
     
     * @return uint256 Token ID.
     */
    function nextTokenId() external view returns (uint256) {
        return _nextTokenId();
    }

    /**
     * @dev Mints a {quantity} of NFTs and sends them to the {recipient}.
     * @param recipient - Receiver of NFTs.
     * @param quantity - Quantity of NFTs to mint.
     
     * Note: This function can only be called by owner.
     */
    function mint(address recipient, uint256 quantity) external onlyOwner {
        _safeMint(recipient, quantity);
    }

    /**
     * @dev Sets {_tokenURI} for a specified {tokenId}.
     * @param tokenId - Token ID to set URI for.
     * @param _tokenURI - Token URI.
     
     * Note: This function can only be called by owner.
     */
    function setURIForTokenId(uint256 tokenId, string memory _tokenURI) external onlyOwner {
        tokenURIs[tokenId] = _tokenURI;
    }

    /**
     * @dev Sets default royalty for this collection.
     * @param receiver - Royalty receiver.
     * @param feeNumerator - Royalty amount. [10000 == 100%].
     
     * Note: This function can only be called by owner.
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @dev Sets royalty for a single {tokenId} in the collection.
     * @param tokenId - Token ID to set royalty for.
     * @param receiver - Royalty receiver.
     * @param feeNumerator - Royalty amount. [10000 == 100%].
     
     * Note: This function can only be called by owner.
     */
    function setRoyaltyForTokenId(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyOwner {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function _baseURI() internal view override returns (string memory) {
        return URI;
    }

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

    function supportsInterface(bytes4 interfaceId) public view override(ERC721A, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
