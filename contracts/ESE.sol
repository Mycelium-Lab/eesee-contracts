// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface for eesee with automatic vesting mechanism.
 */
contract ESE is Context, IERC20, IERC20Metadata {
    struct Beneficiary{
        uint256 amount;
        address addr;
    }

    struct VestingParams{
        uint256 amount;
        uint256 cliff;
        uint256 duration;// Duration without cliff
        mapping(address => uint256) amounts;
    }

    struct ConstructorVestingParams{
        uint256 cliff;
        uint256 duration;
        uint256 TGEMintShare;// %'s with 10000 as denominator
        Beneficiary[] beneficiaries;
    }
    
    ///@dev Vesting parameters.
    VestingParams[] public vestingStages;

    ///@dev Token generation event.
    uint256 public immutable TGE;

    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _released;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    uint256 private _totalReleased;
    uint256 private _totalVesting;
    string private _name;
    string private _symbol;

    uint256 private constant denominator = 10000;

    constructor(ConstructorVestingParams[] memory _vestingStages) {
        for (uint256 i = 0; i < _vestingStages.length; i++) {
           _initCrowdsaleParams(_vestingStages[i]);
        }
        // Overflow check
        uint256 maxSupply = _totalSupply + _totalVesting;

        //TODO: liquidity

        _name = "eesee";
        _symbol = "$ESE";
        TGE = block.timestamp;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() external view returns (uint256) {
        unchecked{
            return _totalSupply + _totalReleasableAmount();
        }
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) external view returns (uint256) {
        unchecked{
            return _balances[account] + _releasableAmount(account);
        }
    }

    /**
     * @dev Info on how many tokens have already been vested during 3 vesting periods in total.
     */
    function totalVestedAmount(uint256 stage) external view returns(uint256){
        return _totalVestedAmount(vestingStages[stage]);
    }

    /**
     * @dev Info on how many tokens have already been vested during 3 vesting periods for account.
     */
    function vestedAmount(uint256 stage, address account) external view returns(uint256){
        return _vestedAmount(vestingStages[stage], account);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 releasableAmount = _releasableAmount(from);
        unchecked {
            uint256 fromBalance = _balances[from] + releasableAmount;
            require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
            _balances[from] = fromBalance - amount;

            // Overflow not possible: _totalReleased is capped by _totalSupplyAfterVesting.
            if(releasableAmount > 0){
                _totalReleased += releasableAmount;
                _released[from] += releasableAmount;

                emit Transfer(address(0), from, releasableAmount);
            }
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        //Check for overflows
        uint256 maxSupply = _totalSupply + _totalVesting;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _initCrowdsaleParams(ConstructorVestingParams memory crowdsaleParams) internal {
        VestingParams storage crowdsale = vestingStages.push();

        crowdsale.cliff = crowdsaleParams.cliff;
        crowdsale.duration = crowdsaleParams.duration;
        uint256 totalVestingAmount;
        for(uint256 i; i < crowdsaleParams.beneficiaries.length;){
            require (crowdsaleParams.TGEMintShare <= denominator, "ESE: Invalid TGEMintShare");
            uint256 TGEMint = crowdsaleParams.beneficiaries[i].amount * crowdsaleParams.TGEMintShare / denominator;
            if(TGEMint != 0){
                _mint(crowdsaleParams.beneficiaries[i].addr, TGEMint);
            }

            uint256 vestingAmount = crowdsaleParams.beneficiaries[i].amount - TGEMint;
            crowdsale.amounts[crowdsaleParams.beneficiaries[i].addr] += vestingAmount;
            totalVestingAmount += vestingAmount;
            unchecked{ i++; }
        }
        crowdsale.amount = totalVestingAmount;
        _totalVesting += totalVestingAmount;
    }

    /**
     * @dev Calculates the amount that has already vested but hasn't been released yet.
     */
    function _totalReleasableAmount() internal view returns(uint256 amount){
        unchecked{
            for(uint256 i; i < vestingStages.length; i++){
                amount += _totalVestedAmount(vestingStages[i]);
            }
            amount -= _totalReleased;
        }
    }

    /**
     * @dev Calculates the amount that has already vested for a given vesting period in total.
     * @param vesting - Vesting period to check.
     */
    function _totalVestedAmount(VestingParams storage vesting) internal view returns (uint256) {
        if(vesting.amount == 0) {
            return 0;
        }

        uint256 start = TGE + vesting.cliff;
        if (block.timestamp < start) {
            return 0;
        }
        if (block.timestamp >= start + vesting.duration) {
            return vesting.amount;
        }
        return vesting.amount * (block.timestamp - start) / vesting.duration;
    }

    /**
     * @dev Calculates the amount that has already vested but hasn't been released yet for an account.
     * @param account - Address to check.
     */
    function _releasableAmount(address account) internal view returns(uint256 amount){
        unchecked{
            for(uint256 i; i < vestingStages.length; i++){
                amount += _vestedAmount(vestingStages[i], account);
            }
            amount -= _released[account];
        }
    }

    /**
     * @dev Calculates the amount that has already vested for a given vesting period for an account.
     * @param vesting - Vesting period to check.
     * @param account - Address to check.
     */
    function _vestedAmount(VestingParams storage vesting, address account) internal view returns (uint256) {
        if(vesting.amounts[account] == 0) {
            return 0;
        }
        uint256 start = TGE + vesting.cliff;
        if (block.timestamp < start) {
            return 0;
        }
        if (block.timestamp >= start + vesting.duration) {
            return vesting.amounts[account];
        }
        return vesting.amounts[account] * (block.timestamp - start) / vesting.duration;
    }
}
