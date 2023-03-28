//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract MockVRFCoordinator {
    uint256 internal counter = 0;

    function requestRandomWords(
        bytes32,
        uint64,
        uint16,
        uint32 callbackGasLimit,
        uint32
    ) external returns (uint256 requestId) {
        VRFConsumerBaseV2 consumer = VRFConsumerBaseV2(msg.sender);
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = counter;
        consumer.rawFulfillRandomWords{gas: callbackGasLimit}(requestId, randomWords);
        counter += 1;
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