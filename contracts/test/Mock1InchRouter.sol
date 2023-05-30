// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library UniERC20 {
    using SafeERC20 for IERC20;

    error InsufficientBalance();
    error ApproveCalledOnETH();
    error NotEnoughValue();
    error FromIsNotSender();
    error ToIsNotThis();
    error ETHTransferFailed();

    uint256 private constant _RAW_CALL_GAS_LIMIT = 5000;
    IERC20 private constant _ETH_ADDRESS = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    IERC20 private constant _ZERO_ADDRESS = IERC20(address(0));

    function isETH(IERC20 token) internal pure returns (bool) {
        return (token == _ZERO_ADDRESS || token == _ETH_ADDRESS);
    }

    function uniBalanceOf(IERC20 token, address account) internal view returns (uint256) {
        if (isETH(token)) {
            return account.balance;
        } else {
            return token.balanceOf(account);
        }
    }

    /// @dev note that this function does nothing in case of zero amount
    function uniTransfer(IERC20 token, address payable to, uint256 amount) internal {
        if (amount > 0) {
            if (isETH(token)) {
                if (address(this).balance < amount) revert InsufficientBalance();
                // solhint-disable-next-line avoid-low-level-calls
                (bool success, ) = to.call{value: amount, gas: _RAW_CALL_GAS_LIMIT}("");
                if (!success) revert ETHTransferFailed();
            } else {
                token.safeTransfer(to, amount);
            }
        }
    }
}

/// @title Interface for making arbitrary calls during swap
interface IAggregationExecutor {
    /// @notice propagates information about original msg.sender and executes arbitrary data
    function execute(address msgSender, bytes memory data, uint256 amount) external payable;  // 0x4b64e492
}


contract Mock1InchRouter {
    using UniERC20 for IERC20;
    using SafeERC20 for IERC20;

    error ZeroMinReturn();
    error ZeroReturnAmount();
    error ReturnAmountIsNotEnough();
    error InvalidMsgValue();
    error EthDepositRejected();

    receive() external payable {
        // solhint-disable-next-line avoid-tx-origin
        if (msg.sender == tx.origin) revert EthDepositRejected();
    }

    uint256 private constant _PARTIAL_FILL = 1 << 0;
    uint256 private constant _REQUIRES_EXTRA_ETH = 1 << 1;

    struct SwapDescription {
        IERC20 srcToken;
        IERC20 dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }

    /// @notice Performs a swap, delegating all calls encoded in `data` to `executor`. See tests for usage examples
    /// @dev router keeps 1 wei of every token on the contract balance for gas optimisations reasons. This affects first swap of every token by leaving 1 wei on the contract.
    /// @param executor Aggregation executor that executes calls described in `data`
    /// @param desc Swap description
    /// @param permit Should contain valid permit that can be used in `IERC20Permit.permit` calls.
    /// @param data Encoded calls that `caller` should execute in between of swaps
    /// @return returnAmount Resulting token amount
    /// @return spentAmount Source token amount
    function swap(
        IAggregationExecutor executor,
        SwapDescription calldata desc,
        bytes calldata permit,
        bytes calldata data
    )
        external
        payable
        returns (
            uint256 returnAmount,
            uint256 spentAmount
        )
    {
        if (desc.minReturnAmount == 0) revert ZeroMinReturn();//NOT

        IERC20 srcToken = desc.srcToken;
        IERC20 dstToken = desc.dstToken;

        bool srcETH = srcToken.isETH();//NO
        if (msg.value != (srcETH ? desc.amount : 0)) revert InvalidMsgValue();//NO

        if (!srcETH) {
            srcToken.safeTransferFrom(msg.sender, desc.srcReceiver, desc.amount);//NO
        }

        executor.execute(msg.sender, data, desc.amount);

        spentAmount = desc.amount;
        // we leave 1 wei on the router for gas optimisations reasons
        returnAmount = dstToken.uniBalanceOf(address(this));
        if (returnAmount == 0) revert ZeroReturnAmount();
        unchecked { returnAmount--; }

        uint256 unspentAmount = srcToken.uniBalanceOf(address(this));
        if (unspentAmount > 1) {
            // we leave 1 wei on the router for gas optimisations reasons
            unchecked { unspentAmount--; }
            spentAmount -= unspentAmount;
            srcToken.uniTransfer(payable(msg.sender), unspentAmount);
        }
        if (returnAmount * desc.amount < desc.minReturnAmount * spentAmount) revert ReturnAmountIsNotEnough();

        address payable dstReceiver = (desc.dstReceiver == address(0)) ? payable(msg.sender) : desc.dstReceiver;
        dstToken.uniTransfer(dstReceiver, returnAmount);
    }
}
