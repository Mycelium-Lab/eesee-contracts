//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract MockVRFCoordinator {
    struct VRF{
        VRFConsumerBaseV2 consumer;
        uint32 callbackGasLimit;
    }
    uint256 internal counter = 0;

    mapping(uint256 => VRF) vrf;

    function requestRandomWords(
        bytes32,
        uint64,
        uint16,
        uint32 callbackGasLimit,
        uint32
    ) external returns (uint256) {
        VRFConsumerBaseV2 consumer = VRFConsumerBaseV2(msg.sender);

        vrf[counter].consumer = consumer;
        vrf[counter].callbackGasLimit = callbackGasLimit;
        uint256 _counter = counter;
        counter += 1;
        return _counter;
    }

    function fulfillWords(uint256 requestId) external {
        require(address(vrf[requestId].consumer) != address(0), "requestId NOT EXISTS");
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = requestId;
        vrf[requestId].consumer.rawFulfillRandomWords{gas: vrf[requestId].callbackGasLimit}(requestId, randomWords);
    }

    //NOTE: This is not view by design
    function createSubscription() external returns (uint64 subscriptionID) {
        return 0;
    }
    //NOTE: This is not view by design
    function addConsumer(uint64, address) external {
        return;
    }
}