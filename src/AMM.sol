// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @custom:info This contract have been refactored by an ai(deepseek v4.1 flash) not the core logic but only for best practices.
/// @custom:info You can find the original contract in this link: https://github.com/Asout3/Relearn_and_prac/blob/main/src/AMM.sol

/**
 * @title IERC20
 * @notice Minimal ERC20 interface used by the AMM to interact with
 *         the two underlying tokens.
 */
interface IERC20 {
    /**
     * @notice Moves `_amount` tokens from `_from` to `_to` using the caller's allowance.
     * @param _from  Address holding the tokens.
     * @param _to    Recipient address.
     * @param _amount Number of tokens to move.
     * @return True on success.
     */
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool);

    /**
     * @notice Moves `_amount` tokens from the caller to `_to`.
     * @param _to     Recipient address.
     * @param _amount Number of tokens to move.
     * @return True on success.
     */
    function transfer(address _to, uint256 _amount) external returns (bool);

    /**
     * @notice Returns the token balance of `_address`.
     * @param _address Address to query.
     * @return The token balance.
     */
    function balanceOf(address _address) external view returns (uint256);
}

/**
 * @title LP
 * @notice Liquidity-provider share token for the AMM.
 * @dev    Only the owner (the AMM that deployed this token) may mint or burn.
 */
contract LP {
    /// @notice Thrown when the caller's allowance is too low for a `transferFrom`.
    error InsufficentAllowance();
    /// @notice Thrown when the sender's balance is too low for a transfer.
    error InsufficentBalance();

    /// @notice Emitted on every LP-token transfer.
    event Transfer(address indexed sender, address indexed receiver, uint256 amount);
    /// @notice Emitted on every approval.
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Total supply of LP shares.
    uint256 public totalSupply;
    /// @notice Internal balance mapping (owner => balance).
    mapping(address => uint256) private _balanceOf;
    /// @notice Allowance mapping (owner => spender => amount).
    mapping(address => mapping(address => uint256)) public allowance;
    /// @notice Human-readable token name.
    string public name;
    /// @notice Token symbol.
    string public symbol;
    /// @notice Number of decimals.
    uint8 public decimals;
    /// @notice Owner of this token (the AMM). Only the owner can mint/burn.
    address public owner;

    /**
     * @notice Deploys a new LP token.
     * @param _name         Token name.
     * @param _symbol       Token symbol.
     * @param _decimals     Number of decimals.
     * @param _totalSupply  Initial total supply (usually 0).
     */
    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _totalSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply;
        owner = msg.sender;
    }

    /**
     * @notice Returns the current total supply of LP shares.
     * @return The total supply.
     */
    function totalSupplies() external view returns (uint256) {
        return totalSupply;
    }

    /**
     * @notice Returns the LP balance of `_address`.
     * @param _address Address to query.
     * @return The LP balance.
     */
    function balanceOf(address _address) external view returns (uint256) {
        return _balanceOf[_address];
    }

    /**
     * @notice Returns `true` if `_owner` has granted any allowance to `_to`.
     * @param _owner Allowance owner.
     * @param _to    Approved spender.
     * @return True if allowance is non-zero.
     */
    function checkApproval(address _owner, address _to) external view returns (bool) {
        if (allowance[_owner][_to] == 0) return false;

        return true;
    }

    /**
     * @notice Mints `_amount` new LP shares to `_to`. Owner only.
     * @param _amount Number of shares to mint.
     * @param _to     Recipient of the new shares.
     */
    function mint(uint256 _amount, address _to) external {
        require(owner == msg.sender, "you are not the owner of this token");
        totalSupply += _amount;
        _balanceOf[_to] += _amount;
    }

    /**
     * @notice Burns `_amount` LP shares from `_from`. Owner only.
     * @param _from   Address whose shares are burned.
     * @param _amount Number of shares to burn.
     */
    function burn(address _from, uint256 _amount) external {
        require(owner == msg.sender, "not owner");
        require(_balanceOf[_from] >= _amount, "insufficient");
        _balanceOf[_from] -= _amount;
        totalSupply -= _amount;
    }

    /**
     * @notice Transfers `_amount` LP shares from the caller to `_to`.
     * @param _to     Recipient address.
     * @param _amount Number of shares to transfer.
     * @return True on success.
     */
    function transfer(address _to, uint256 _amount) external returns (bool) {
        if (_balanceOf[msg.sender] < _amount) revert InsufficentBalance();

        _balanceOf[msg.sender] -= _amount;
        _balanceOf[_to] += _amount;

        emit Transfer(msg.sender, _to, _amount);
        return true;
    }

    /**
     * @notice Approves `_spender` to spend up to `_amount` shares of the caller.
     * @param _spender Spender address.
     * @param _amount  Allowance amount.
     * @return True on success.
     */
    function approve(address _spender, uint256 _amount) external returns (bool) {
        allowance[msg.sender][_spender] = _amount;

        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    /**
     * @notice Transfers `_amount` shares from `_from` to `_to` using the caller's allowance.
     * @param _from   Source address.
     * @param _to     Recipient address.
     * @param _amount Number of shares to transfer.
     * @return True on success.
     */
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool) {
        if (allowance[_from][msg.sender] < _amount) revert InsufficentAllowance();
        if (_balanceOf[_from] < _amount) revert InsufficentBalance();

        allowance[_from][msg.sender] -= _amount;
        _balanceOf[_from] -= _amount;
        _balanceOf[_to] += _amount;

        emit Transfer(_from, _to, _amount);
        return true;
    }
}

/**
 * @title AMM
 * @notice Constant-product AMM (`reserveA * reserveB = k`) for two ERC20 tokens.
 * @dev    Invariant `reserveA * reserveB` should remain unchanged across swaps
 *         (modulo integer rounding). LP shares are tracked by an internal `LP` token.
 */
contract AMM {
    /// @notice Thrown when a user tries to remove more LP than they hold.
    error InsufficientLiquidity();
    /// @notice Thrown when a zero amount is passed into a state-changing function.
    error CantDoZeroAmounts();

    //////////////////////////////////////////////////////////
    //                  state variables                    //
    ////////////////////////////////////////////////////////

    /// @notice First token of the pair.
    IERC20 public tokenA;
    /// @notice Second token of the pair.
    IERC20 public tokenB;
    /// @notice LP share token for this pool.
    LP public lpToken;
    /// @notice Current reserve of tokenA held by the pool.
    uint256 public reserveA;
    /// @notice Current reserve of tokenB held by the pool.
    uint256 public reserveB;

    /**
     * @notice Deploys a new AMM pool for `_tokenA` / `_tokenB` and its LP token.
     * @param _tokenA Address of the first token.
     * @param _tokenB Address of the second token.
     */
    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        lpToken = new LP("liqudity provider token", "LP", 18, 0);
    }

    /**
     * @notice Deposits both tokens and mints LP shares to the caller.
     * @dev    First deposit mints `sqrt(_amountA * _amountB)` shares; subsequent
     *         deposits mint the minimum of the two proportional calculations.
     * @param _amountA Amount of tokenA to deposit.
     * @param _amountB Amount of tokenB to deposit.
     */
    function addLiquidity(uint256 _amountA, uint256 _amountB) external {
        if (_amountA == 0 || _amountB == 0) revert CantDoZeroAmounts();
        uint256 share;

        if (lpToken.totalSupplies() == 0) {
            share = sqrt(_amountA * _amountB);
        } else {
            share =
                min((_amountA * lpToken.totalSupplies()) / reserveA, (_amountB * lpToken.totalSupplies()) / reserveB);
        }

        reserveA += _amountA;
        reserveB += _amountB;

        bool success1 = tokenA.transferFrom(msg.sender, address(this), _amountA);
        require(success1, "transaction failed");
        bool success2 = tokenB.transferFrom(msg.sender, address(this), _amountB);
        require(success2, "transaction failed");

        lpToken.mint(share, msg.sender);
    }

    /**
     * @notice Burns `_shares` LP shares and returns the proportional underlying tokens.
     * @param _shares Amount of LP shares to burn.
     */
    function removeLiquidity(uint256 _shares) external {
        if (_shares == 0) revert CantDoZeroAmounts();
        if (lpToken.balanceOf(msg.sender) < _shares) revert InsufficientLiquidity();

        uint256 amountA = (_shares * reserveA) / lpToken.totalSupplies();
        uint256 amountB = (_shares * reserveB) / lpToken.totalSupplies();

        lpToken.burn(msg.sender, _shares);

        bool success1 = tokenA.transfer(msg.sender, amountA);
        require(success1, "transfer failed");
        reserveA -= amountA;

        bool success2 = tokenB.transfer(msg.sender, amountB);
        require(success2, "transfer failed");
        reserveB -= amountB;
    }

    /**
     * @notice Swaps `_amountTokenA` of tokenA for tokenB.
     * @dev    Uses the constant-product formula:
     *         `amountOut = (reserveB * _amountTokenA) / (reserveA + _amountTokenA)`.
     * @param _amountTokenA Amount of tokenA being swapped in.
     */
    function swapAforB(uint256 _amountTokenA) external {
        if (_amountTokenA == 0) revert CantDoZeroAmounts();

        uint256 amountOut = (reserveB * _amountTokenA) / (reserveA + _amountTokenA);

        reserveA += _amountTokenA;
        reserveB -= amountOut;

        bool success1 = tokenA.transferFrom(msg.sender, address(this), _amountTokenA);
        require(success1, "transfer failed");

        bool success2 = tokenB.transfer(msg.sender, amountOut);
        require(success2, "transfer failed");
    }

    /**
     * @notice Swaps `_amountTokenB` of tokenB for tokenA.
     * @dev    Uses the constant-product formula:
     *         `amountOut = (reserveA * _amountTokenB) / (reserveB + _amountTokenB)`.
     * @param _amountTokenB Amount of tokenB being swapped in.
     */
    function swapBforA(uint256 _amountTokenB) external {
        if (_amountTokenB == 0) revert CantDoZeroAmounts();

        uint256 amountOut = (reserveA * _amountTokenB) / (reserveB + _amountTokenB);

        reserveB += _amountTokenB;
        reserveA -= amountOut;

        bool success1 = tokenB.transferFrom(msg.sender, address(this), _amountTokenB);
        require(success1, "transfer failed");

        bool success2 = tokenA.transfer(msg.sender, amountOut);
        require(success2, "transfer failed");
    }

    //////////////////////////////////////////////////////////
    //                  Helper functions                   //
    /////////////////////////////////////////////////////////

    /**
     * @notice Computes the integer square root of `_y` (Babylonian method).
     * @dev    Used for the first-deposit LP share calculation. Returns 0 if `_y` is 0.
     * @param _y Value to compute the square root of.
     * @return z The integer square root of `_y`.
     */
    function sqrt(uint256 _y) internal pure returns (uint256 z) {
        if (_y > 3) {
            z = _y;
            uint256 x = _y / 2 + 1;
            while (x < z) {
                z = x;
                x = (_y / x + x) / 2;
            }
        } else if (_y != 0) {
            z = 1;
        }
    }

    /**
     * @notice Returns the smaller of two values.
     * @param _a First value.
     * @param _b Second value.
     * @return The smaller of `_a` and `_b`.
     */
    function min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a < _b ? _a : _b;
    }
}
