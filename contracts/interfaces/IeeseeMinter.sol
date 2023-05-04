// Because of the contract size limit we need a sepparate contract to mint NFTs.
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/IeeseeNFTDrop.sol";

interface IeeseeMinter {
    function publicCollection() external view returns(IERC721);
    function mintToPublicCollection(uint256 amount, string[] memory tokenURIs, address royaltyReceiver, uint96 royaltyFeeNumerator) external returns(IERC721 collection, uint256[] memory tokenIDs);
    function mintToPrivateCollection(
        uint256 amount,
        string memory name, 
        string memory symbol, 
        string memory baseURI, 
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external returns(IERC721 collection, uint256[] memory tokenIDs);
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
    ) external returns(IERC721 collection);
}
