// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IAnycallConfig {
    function checkCall(
        address _sender,
        bytes calldata _data,
        uint256 _toChainID,
        uint256 _flags
    ) external view returns (string memory _appID, uint256 _srcFees);

    function checkExec(
        string calldata _appID,
        address _from,
        address _to
    ) external view;

    function chargeFeeOnDestChain(address _from, uint256 _prevGasLeft) external;

    function deposit(address _account) external payable;

    function withdraw(uint256 _amount) external;

    function executionBudget(address _account) external view returns (uint256);
}