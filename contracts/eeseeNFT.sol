//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract eeseeNFT is ERC721A, Ownable {
    string public URI;
    constructor(string memory name, string memory symbol, string memory _URI) ERC721A(name, symbol) {
        URI = _URI;
    }

    function mint(uint256 quantity) external onlyOwner {
        _safeMint(msg.sender, quantity);
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
