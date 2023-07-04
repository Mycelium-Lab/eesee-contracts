// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract MockAggregator {
    function latestRoundData() external pure returns(
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) {
        return (0,1 ether,0,0,0);
    }
}