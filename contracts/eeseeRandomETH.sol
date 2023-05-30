// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import '@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol';
import '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol'; 

contract eeseeRandomETH is VRFConsumerBaseV2, AxelarExecutable {
    struct RequestData {
        uint256 ID;
        uint256 maxNumber;
    }
    /// @dev Axelar request data from source chain.
    mapping(uint256 => RequestData) public requests;

    /// @dev Axelar gas service.
    IAxelarGasService immutable public gasService;
    ///@dev eesee contract chain.
    string public eeseeChain;
    ///@dev eesee contract address.
    string public eeseeAddress;
    bytes32 immutable private eeseeHash;

    ///@dev ChainLink Matic/ETH price feed
    AggregatorV3Interface immutable public priceFeed_MATIC_ETH;

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

    constructor(
        address _gateway, 
        IAxelarGasService _gasService,
        string memory _eeseeChain, 
        string memory _eeseeAddress,
        AggregatorV3Interface _priceFeed_MATIC_ETH,
        address _vrfCoordinator, 
        LinkTokenInterface _LINK,
        bytes32 _keyHash,
        uint16 _minimumRequestConfirmations,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) AxelarExecutable(_gateway) {
        gasService = _gasService;
        eeseeChain = _eeseeChain;
        eeseeAddress = _eeseeAddress;
        eeseeHash = keccak256(abi.encodePacked(eeseeChain, eeseeAddress));

        priceFeed_MATIC_ETH = _priceFeed_MATIC_ETH;

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

    function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) internal override {
        require(keccak256(abi.encodePacked(sourceChain, sourceAddress)) == eeseeHash, "eesee: Incorrect caller");
        (uint256 ID, uint256 maxNumber) = abi.decode(payload, (uint256, uint256));
        uint256 requestID = vrfCoordinator.requestRandomWords(keyHash, subscriptionID, minimumRequestConfirmations, callbackGasLimit, 1);

        requests[requestID] = RequestData({
            ID: ID,
            maxNumber: maxNumber
        });
    }

    function fulfillRandomWords(uint256 requestID, uint256[] memory randomWords) internal override {
        RequestData memory request = requests[requestID];
        delete requests[requestID];

        uint256 chosenTicket = randomWords[0] % request.maxNumber;

        bytes memory payload = abi.encode(request.ID, chosenTicket);
        (,int256 answer,,,) = priceFeed_MATIC_ETH.latestRoundData();
        require(answer > 0, "eesee: Unstable pricing");

        uint256 numerator = 10^priceFeed_MATIC_ETH.decimals();
        uint256 networkBaseFee = 1045291489992079548;//TODO: calc for mainnet
        //Note: This contract must have [80000 gas limit * 500 gwei] ETH. We divide by {answer} to get amount in Matic.
        //TODO: This is too low for some reason
        //TODO: this is not a good design
        uint256 executionFee = 80000 * 500 gwei * numerator / uint256(answer);
        gasService.payNativeGasForContractCall{value: networkBaseFee + executionFee}(
            address(this),
            eeseeChain,
            eeseeAddress,
            payload,
            msg.sender
        );
        gateway.callContract(eeseeChain, eeseeAddress, payload);
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

    ///@dev To call payNativeGasForContractCall this contract must have Matic in it.
    receive() external payable {}
}