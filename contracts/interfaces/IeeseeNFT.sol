// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IeeseeNFT {
    error SetURIForNonexistentToken();
    error SetRoyaltyForNonexistentToken();

    function URI() external view returns (string memory);
    function contractURI() external view returns (string memory);
    function nextTokenId() external view returns (uint256);
    function mint(address recipient, uint256 quantity) external;
    function setURIForTokenId(uint256 tokenId, string memory _tokenURI) external;
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external;
    function setRoyaltyForTokenId(uint256 tokenId, address receiver, uint96 feeNumerator) external;
}
