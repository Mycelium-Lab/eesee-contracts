// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import '@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol';
import '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol'; 

contract eeseeRandom is VRFConsumerBaseV2, AxelarExecutable {
    //sourceAddress is string to save gas on string-address-string conversions
    struct RequestData {
        uint256 ID;
        string sourceChain;
        string sourceAddress;
        uint256 maxNumber;
    }
    mapping(uint256 => RequestData) public requests;

    IAxelarGasService public immutable gasService;

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

    ///@dev ChainLink Matic/ETH price feed
    //TODO:0x327e23A4855b6F663a28c5161541d69Af8973302 on polygon
    AggregatorV3Interface public immutable priceFeed;

    constructor(
        address _gateway, 
        IAxelarGasService _gasService,
        address _vrfCoordinator, 
        LinkTokenInterface _LINK,
        bytes32 _keyHash,
        uint16 _minimumRequestConfirmations,
        uint32 _callbackGasLimit,
        AggregatorV3Interface _priceFeed
    ) VRFConsumerBaseV2(_vrfCoordinator) AxelarExecutable(_gateway) {
        gasService = _gasService;

        // ChainLink stuff. Create subscription for VRF V2.
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionID = vrfCoordinator.createSubscription();
        vrfCoordinator.addConsumer(subscriptionID, address(this));
        LINK = _LINK;
        keyHash = _keyHash;
        minimumRequestConfirmations = _minimumRequestConfirmations;
        callbackGasLimit = _callbackGasLimit;

        priceFeed = _priceFeed;
    }

    // ============ Internal Methods ============

    //TODO: make sure this can only be called by eesee SC
    function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) internal override {
        (uint256 ID, uint256 maxNumber) = abi.decode(payload, (uint256, uint256));
        uint256 requestID = vrfCoordinator.requestRandomWords(keyHash, subscriptionID, minimumRequestConfirmations, callbackGasLimit, 1);

        requests[requestID] = RequestData({
            ID: ID,
            sourceChain: sourceChain,
            sourceAddress: sourceAddress,
            maxNumber: maxNumber
        });
    }


    function fulfillRandomWords(uint256 requestID, uint256[] memory randomWords) internal override {
        RequestData memory request = requests[requestID];
        delete requests[requestID];

        uint256 chosenTicket = randomWords[0] % request.maxNumber;

        bytes memory payload = abi.encode(request.ID, chosenTicket);
        (,int256 answer,,,) = priceFeed.latestRoundData();
        require(answer > 0, "eesee: Unstable pricing");
        //Note: This contract must have [40000 gas limit * 500 gwei] ETH. We divie by {answer} to get amount in Matic.
        gasService.payNativeGasForContractCall{value: 40000 * 500 gwei * 1 ether / answer}(
            address(this),
            request.sourceChain,
            request.sourceAddress,
            payload,
            msg.sender
        );
        gateway.callContract(request.sourceChain, request.sourceAddress, payload);
    }

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

    ///@dev To call payNativeGasForContractCall this contract must have ETH in it.
    receive() external payable {}
}