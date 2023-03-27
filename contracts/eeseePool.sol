// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

//TODO: recheck everything + tests
//TODO: comments
contract eeseePool is Ownable{
    struct Claim {
        uint256 rewardID;
        uint256 balance;
        bytes32[] merkleProof;
    }

    IERC20 public rewardToken;// don't need safeTransfer
    uint256 public rewardID;
    mapping(uint256 => bytes32) public rewardRoot;
    mapping(address => mapping(uint256 => bool)) public isClaimed;

    event RewardAdded(
        uint256 indexed rewardID,
        bytes32 merkleRoot
    );
    
    event RewardClaimed(
        uint256 indexed rewardID,
        address indexed claimer,
        uint256 amount
    );

    constructor(IERC20 _rewardToken) {
        rewardToken = _rewardToken;
    }

    function claimRewards(Claim[] memory claims) external {
        for (uint256 i = 0; i < claims.length; i++) {
            Claim memory claim = claims[i];
            require(verifyClaim(msg.sender, claim), "eesee: Invalid merkle proof");
            require(!isClaimed[msg.sender][claim.rewardID], "eesee: Already claimed");
            isClaimed[msg.sender][claim.rewardID] = true;

            rewardToken.transfer(msg.sender, claim.balance);

            emit RewardClaimed(
                claim.rewardID,
                msg.sender,
                claim.balance
            );
        }
    }

    function addReward(bytes32 merkleRoot) external onlyOwner {
        rewardRoot[rewardID] = merkleRoot;
        emit RewardAdded(rewardID, merkleRoot);
        rewardID += 1;
    }

    function getRewards(address claimer, Claim[] memory claims) external view returns (uint256 rewards) {
        for (uint256 i = 0; i < claims.length; i++) {
            Claim memory claim = claims[i];
            if(verifyClaim(claimer, claim) && !isClaimed[claimer][claim.rewardID]){
                rewards += claim.balance;
            }
        }
    }

    function verifyClaim(address claimer, Claim memory claim) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(claimer, claim.balance));
        return MerkleProof.verify(claim.merkleProof, rewardRoot[claim.rewardID], leaf);
    }
}