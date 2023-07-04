// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract eeseeMining is Ownable{
    using SafeERC20 for IERC20;
    /**
     * @dev Claim:
     * {rewardID} - RewardID the tokens are claimed for.
     * {balance} - Amount of tokens to claim. 
     * {merkleProof} - Merkle proof to verify claim.
     */
    struct Claim {
        uint256 rewardID;
        uint256 balance;
        bytes32[] merkleProof;
    }

    ///@dev ESE token this contract uses.
    IERC20 public immutable rewardToken;
    ///@dev Current reward ID.
    uint256 public rewardID;
    ///@dev Maps {rewardID} to its merkle root.
    mapping(uint256 => bytes32) public rewardRoot;
    ///@dev Has address claimed reward for {rewardID}.
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

    error InvalidMerkleProof();
    error AlreadyClaimed();

    constructor(IERC20 _rewardToken) {
        if(address(_rewardToken) == address(0)) revert("eeseeMining: Invalid Reward Token");
        rewardToken = _rewardToken;
    }

    /**
     * @dev Claims rewards for multiple {rewardID}s. Emits {RewardClaimed} event for each reward claimed.
     * @param claims - Claim structs.
     */
    function claimRewards(Claim[] memory claims) external{
        for (uint256 i = 0; i < claims.length;) {
            Claim memory claim = claims[i];
            if(!verifyClaim(msg.sender, claim)) revert InvalidMerkleProof();
            if(isClaimed[msg.sender][claim.rewardID]) revert AlreadyClaimed();
            
            isClaimed[msg.sender][claim.rewardID] = true;

            rewardToken.safeTransfer(msg.sender, claim.balance);

            emit RewardClaimed(
                claim.rewardID,
                msg.sender,
                claim.balance
            );
            unchecked{ i++; }
        }
    }

    /**
     * @dev Adds new merkle root and advances to the next {rewardID}. Emits {RewardAdded} event.
     * @param merkleRoot - Merkle root.
     */
    function addReward(bytes32 merkleRoot) external onlyOwner {
        rewardRoot[rewardID] = merkleRoot;
        emit RewardAdded(rewardID, merkleRoot);
        unchecked{ rewardID += 1; }
    }

    /**
     * @dev Verifies {claims} and returns rewards to be claimed from {claims}.
     * @param claimer - Address to check.
     * @param claims - Claims to check.

     * @return rewards - Rewards to be claimed.
     */
    function getRewards(address claimer, Claim[] memory claims) external view returns (uint256 rewards) {
        for (uint256 i = 0; i < claims.length;) {
            Claim memory claim = claims[i];
            if(verifyClaim(claimer, claim) && !isClaimed[claimer][claim.rewardID]){
                rewards += claim.balance;
            }
            unchecked{ i++; }
        }
    }

    /**
     * @dev Verifies {claim} for {claimer}.
     * @param claimer - Address to verify claim for.
     * @param claim - Claim to verify.

     * @return bool - Does {claim} exist in merkle root.
     */
    function verifyClaim(address claimer, Claim memory claim) public view returns (bool) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(claimer, claim.balance))));
        return MerkleProof.verify(claim.merkleProof, rewardRoot[claim.rewardID], leaf);
    }
}