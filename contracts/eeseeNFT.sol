//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

//TODO: check ERC721A contract public functions for vulnerabilities
contract eeseeNFT is ERC721A, ERC2981, Ownable {
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

    //TODO:royalty like opensea!!!
}
