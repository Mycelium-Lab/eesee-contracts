//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "operator-filter-registry/src/DefaultOperatorFilterer.sol";

//TODO: check ERC721A contract public functions for vulnerabilities
contract eeseeNFT is ERC721A, ERC2981, Ownable, DefaultOperatorFilterer {
    string public URI;
    
    // opensea royalty and nft collection info
    string public contractURI;
    
    constructor(
        string memory name, 
        string memory symbol, 
        string memory _URI, 
        string memory _contractURI,
        uint96 royaltyFeesInBips
    ) ERC721A(name, symbol) {
        URI = _URI;
        contractURI = _contractURI;
        _setDefaultRoyalty(msg.sender, royaltyFeesInBips);
    }

    function setContractURI(string memory _contractURI) public onlyOwner() {
        contractURI = _contractURI;
    }

    function mint(uint256 quantity) external onlyOwner {
        _safeMint(msg.sender, quantity);
    }
    function setRoyaltyForTokenID(uint256 tokenId, address receiver, uint96 feeNumerator) public onlyOwner {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }
    function supportsInterface(bytes4 interfaceId)
            public
            view
            override(ERC721A, ERC2981)
            returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    function startTokenId() external pure returns (uint256) {
        return _startTokenId();
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function nextTokenId() external view returns (uint256) {
        return _nextTokenId();
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

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        payable
        public
        override
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }
}
