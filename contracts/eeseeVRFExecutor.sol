// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./interfaces/ICallProxy.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

contract eeseeVRFExecutor is VRFConsumerBaseV2 {
    struct RequestData {
        uint256 ID;
        uint256 maxNumber;
    }
    /// @dev Axelar request data from source chain.
    mapping(uint256 => RequestData) public requests;

    ///@dev Multichain's anyCall contract.
    ICallProxy immutable public AnyCall;
    ///@dev eesee contract chain.
    uint256 immutable public eeseeChain;
    ///@dev eesee contract address.
    address immutable public eeseeAddress;

    ///@dev Chainlink token.
    LinkTokenInterface immutable public LINK;
    ///@dev Chainlink VRF V2 coordinator.
    VRFCoordinatorV2Interface immutable public vrfCoordinator;
    ///@dev Chainlink VRF V2 subscription ID.
    uint64 immutable public subscriptionID;
    ///@dev Chainlink VRF V2 key hash to call requestRandomWords() with.
    bytes32 immutable public keyHash;
    ///@dev Chainlink VRF V2 request confirmations.
    uint16 immutable public minimumRequestConfirmations;
    ///@dev Chainlink VRF V2 gas limit to call fulfillRandomWords().
    uint32 immutable private callbackGasLimit;

    error CallerNotExecutor();
    error InvalidContext();

    constructor(
        ICallProxy _AnyCall, 
        uint256 _eeseeChain, 
        address _eeseeAddress,
        address _vrfCoordinator, 
        LinkTokenInterface _LINK,
        bytes32 _keyHash,
        uint16 _minimumRequestConfirmations,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        AnyCall = _AnyCall;
        eeseeChain = _eeseeChain;
        eeseeAddress = _eeseeAddress;
        
        // ChainLink stuff. Create subscription for VRF V2.
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionID = vrfCoordinator.createSubscription();
        vrfCoordinator.addConsumer(subscriptionID, address(this));
        LINK = _LINK;
        keyHash = _keyHash;
        minimumRequestConfirmations = _minimumRequestConfirmations;
        callbackGasLimit = _callbackGasLimit;
    }

    // ============ Internal Methods ============

    function anyExecute(bytes calldata data) external returns (bool success, bytes memory result){
        address executor = AnyCall.executor();
        if(msg.sender != address(executor)) revert CallerNotExecutor();

        (address from, uint256 fromChainId,) = ICallProxy(executor).context();
        if(from != eeseeAddress || fromChainId != eeseeChain) revert InvalidContext();

        uint256 requestID = vrfCoordinator.requestRandomWords(keyHash, subscriptionID, minimumRequestConfirmations, callbackGasLimit, 1);
        (uint256 ID, uint256 maxNumber) = abi.decode(data, (uint256, uint256));
        requests[requestID] = RequestData({
            ID: ID,
            maxNumber: maxNumber
        });

        return (true, "");
    }

    function fulfillRandomWords(uint256 requestID, uint256[] memory randomWords) internal override {
        RequestData memory request = requests[requestID];
        delete requests[requestID];

        //todo: on dstchain let be the last ticket buyer who pays
        AnyCall.anyCall/*{value: msg.value}*/(
            eeseeAddress,
            abi.encode(request.ID, randomWords[0] % request.maxNumber),
            eeseeChain,
            2,// Pay on dst chain, fallback not allowed//TODO: check that i can't withdraw funcds from eesee 1inch swap that are intener for gas pay
            ""// Extra data used for advanced use cases
        );
    }

    // ============ Admin Methods ============

    /**
     * @dev Fund function for Chainlink's VRF V2 subscription.
     * @param amount - Amount of LINK to fund subscription with.
     */
    function fund(uint96 amount) external {
        LINK.transferFrom(msg.sender, address(this), amount);
        LINK.transferAndCall(
            address(vrfCoordinator),
            amount,
            abi.encode(subscriptionID)
        );
    }
}