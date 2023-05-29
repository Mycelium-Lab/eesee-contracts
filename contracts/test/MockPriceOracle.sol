// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
contract MockPriceOracle {
  int256 immutable private price;
  uint8 immutable private _decimals;
  constructor(int256 _price, uint8 __decimals){
    price = _price;
    _decimals = __decimals;
  }
  function decimals() external view returns (uint8){
    return _decimals;
  }

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ){
        return(0, price, 0, 0, 0);
    }
    function latestAnswer()
    external
    view
    returns (int256 answer){
        return price;
    }
}