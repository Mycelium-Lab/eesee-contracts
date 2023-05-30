// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Crowdsales/Crowdsale/WhitelistTimedCrowdsale.sol";

contract ESE is ERC20, Ownable {
    struct LockedTokens {
        uint256 amount;
        uint256 unlockTimestamp;
    }
    mapping(address => LockedTokens[]) public lockedUserTokens;
    mapping(address => uint256) public presaleLiquidityLockedTokens;
    mapping(address => uint256) public presalePrivateLockedTokens;
    mapping(address => uint256) public lockedTokensAmount;

    address[] public crowdsales;
    WhitelistTimedCrowdsale public privateCrowdsale;
    bool public areCrowdsalesSet;
    uint256 public presaleLiquidityUnlockTimestamp;
    bool public isPresaleLiquidityUnlocked;

    event SetCrowdsales(address[] crowdsales, address privateCrowdsale);
    event LockTokens(
        address recipient,
        uint256 amount,
        uint256 unlockTimestamp
    );
    event LockPresaleLiquidityTokens(address recipient, uint256 amount);
    event LockPresalePrivateTokens(address recipient, uint256 amount);
    event PresaleLiquidityTokensUnlock(uint256 timestamp);

    constructor(uint256 amount) ERC20("eesee", "ESE") {
        //TODO: premint + vesting + IDO - нужно обсуждение с заказчиком
        //TODO: remove this
        _mint(msg.sender, amount);
    }

    modifier onlyCrowdsale() {
        bool isMsgSenderCrowdsale = false;
        for (uint i = 0; i < crowdsales.length; i++) {
            if (msg.sender == crowdsales[i]) {
                isMsgSenderCrowdsale = true;
            }
        }
        require(
            isMsgSenderCrowdsale || msg.sender == address(privateCrowdsale),
            "ESE: only crowdsale contracts can lock tokens"
        );
        _;
    }

    function getTokensAvailableForUnlock(
        address user
    ) public view returns (uint256 totalAvailable) {
        for (uint i = 0; i < lockedUserTokens[user].length; i++) {
            if (lockedUserTokens[user][i].unlockTimestamp <= block.timestamp) {
                totalAvailable += lockedUserTokens[user][i].amount;
            }
        }
        if (privateCrowdsale.hasClosed()) {
            totalAvailable += presalePrivateLockedTokens[user];
        }
        if (
            isPresaleLiquidityUnlocked &&
            block.timestamp >= presaleLiquidityUnlockTimestamp
        ) {
            totalAvailable += presaleLiquidityLockedTokens[user];
        }
    }

    function getTotalLockedTokensAmount(
        address user
    ) public view returns (uint256) {
        return
            lockedTokensAmount[user] +
            presaleLiquidityLockedTokens[user] +
            presalePrivateLockedTokens[user];
    }

    function getLockedUserTokensLength(
        address user
    ) public view returns (uint256) {
        return lockedUserTokens[user].length;
    }

    function getLockedUserTokens(
        address user,
        uint256 index
    ) public view returns (LockedTokens memory) {
        return lockedUserTokens[user][index];
    }

    function setCrowdsales(
        address[] memory _crowdsales,
        address _privateCrowdsale
    ) public onlyOwner {
        require(!areCrowdsalesSet, "ESE: crowdsales have already been set");
        crowdsales = _crowdsales;
        privateCrowdsale = WhitelistTimedCrowdsale(_privateCrowdsale);
        areCrowdsalesSet = true;
        emit SetCrowdsales(crowdsales, _privateCrowdsale);
    }

    function unlockPresaleLiquidityTokens() public onlyOwner {
        require(
            !isPresaleLiquidityUnlocked,
            "ESE: you have already unlocked tokens after liquidity had been added"
        );
        presaleLiquidityUnlockTimestamp = block.timestamp + 180 * 86400;
        isPresaleLiquidityUnlocked = true;
        emit PresaleLiquidityTokensUnlock(presaleLiquidityUnlockTimestamp);
    }

    function lockTokens(
        address recipient,
        uint256 amount,
        uint256 unlockTimestamp
    ) public onlyCrowdsale {
        require(
            amount <= balanceOf(recipient) - getTotalLockedTokensAmount(recipient),
            "ESE: unlocked tokens balance of recipient has to be lower or equal than amount"
        );
        require(
            block.timestamp < unlockTimestamp,
            "ESE: unlock time must be in the future"
        );
        LockedTokens storage lockedTokens = lockedUserTokens[recipient].push();
        lockedTokens.amount = amount;
        lockedTokens.unlockTimestamp = unlockTimestamp;
        lockedTokensAmount[recipient] += amount;
        emit LockTokens(recipient, amount, unlockTimestamp);
    }

    function lockPresaleLiquidityTokens(
        address recipient,
        uint256 amount
    ) public onlyCrowdsale {
        require(
            amount <= balanceOf(recipient) - getTotalLockedTokensAmount(recipient),
            "ESE: unlocked tokens balance of recipient has to be lower or equal than amount"
        );
        presaleLiquidityLockedTokens[recipient] += amount;
        emit LockPresaleLiquidityTokens(recipient, amount);
    }

    function lockPresalePrivateTokens(
        address recipient,
        uint256 amount
    ) public onlyCrowdsale {
        require(
            amount <= balanceOf(recipient) - getTotalLockedTokensAmount(recipient),
            "ESE: unlocked tokens balance of recipient has to be lower or equal than amount"
        );
        presalePrivateLockedTokens[recipient] += amount;
        emit LockPresalePrivateTokens(recipient, amount);
    }

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (lockedTokensAmount[msg.sender] == 0) {
            return super.transfer(to, amount);
        }
        require(
            balanceOf(msg.sender) >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        _unlockTokens(msg.sender);
        if (
            isPresaleLiquidityUnlocked &&
            block.timestamp >= presaleLiquidityUnlockTimestamp
        ) {
            presaleLiquidityLockedTokens[msg.sender] = 0;
        }
        if (privateCrowdsale.hasClosed()) {
            presalePrivateLockedTokens[msg.sender] = 0;
        }
        uint256 totalLockedTokensAmount = getTotalLockedTokensAmount(
            msg.sender
        );
        require(
            balanceOf(msg.sender) - totalLockedTokensAmount >= amount,
            "ESE: not enough unlocked tokens"
        );
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (lockedTokensAmount[from] == 0) {
            return super.transferFrom(from, to, amount);
        }
        require(
            balanceOf(from) >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        _unlockTokens(from);
        if (
            isPresaleLiquidityUnlocked &&
            block.timestamp >= presaleLiquidityUnlockTimestamp
        ) {
            presaleLiquidityLockedTokens[from] = 0;
        }
        if (privateCrowdsale.hasClosed()) {
            presalePrivateLockedTokens[from] = 0;
        }
        uint256 totalLockedTokensAmount = getTotalLockedTokensAmount(from);
        require(
            balanceOf(from) - totalLockedTokensAmount >= amount,
            "ESE: not enough unlocked tokens"
        );
        return super.transferFrom(from, to, amount);
    }

    function _unlockTokens(address from) internal {
        uint i = 0;
        while (i < lockedUserTokens[from].length) {
            if (lockedUserTokens[from][i].unlockTimestamp <= block.timestamp) {
                lockedTokensAmount[from] -= lockedUserTokens[from][i].amount;
                lockedUserTokens[from][i] = lockedUserTokens[from][
                    lockedUserTokens[from].length - 1
                ];
                lockedUserTokens[from].pop();
            } else {
                i++;
            }
        }
    }
}
