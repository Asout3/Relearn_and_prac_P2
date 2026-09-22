// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 *                               $$\   $$\
 *                               $$ |  $$ |
 * $$\    $$\ $$$$$$\  $$\   $$\ $$ |$$$$$$\
 * \$$\  $$  |\____$$\ $$ |  $$ |$$ |\_$$  _|
 *  \$$\$$  / $$$$$$$ |$$ |  $$ |$$ |  $$ |
 *   \$$$  / $$  __$$ |$$ |  $$ |$$ |  $$ |$$\
 *    \$  /  \$$$$$$$ |\$$$$$$  |$$ |  \$$$$  |
 *     \_/    \_______| \______/ \__|   \____/
 *
 *
 *
 */

/// @custom:refactored This contract was refactored with improved documentation and minor Solidity best-practice updates.
/// @custom:source Original contract: https://github.com/Asout3/Relearn_and_prac/blob/main/src/Vault.sol (phase one)

/**
 * @title IAsout3Token
 * @author Mikiyas Yimer.
 * @notice Minimal interface for the underlying ERC20-style token used by the vault.
 * @dev Only the functions required by the vault are declared.
 */
interface IAsout3Token {
    /**
     * @notice Transfers tokens from one address to another using an allowance.
     * @param _from Address to transfer tokens from.
     * @param _to Address to transfer tokens to.
     * @param _amount Amount of tokens to transfer.
     * @return success True if the transfer succeeded.
     */
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool);

    /**
     * @notice Transfers tokens to another address.
     * @param _to Address to transfer tokens to.
     * @param _amount Amount of tokens to transfer.
     * @return success True if the transfer succeeded.
     */
    function transfer(address _to, uint256 _amount) external returns (bool);

    /**
     * @notice Returns the token balance of an address.
     * @param _address Address to query.
     * @return The token balance of `_address`.
     */
    function balanceOf(address _address) external view returns (uint256);
}

/**
 * @title ShareToken
 * @author Mikiyas Yimer.
 * @notice Minimal ERC20-like share token used by the vault.
 * @dev This is not a complete ERC20 implementation. It only exposes the functionality
 *      needed by the vault, plus a small allowance helper.
 */
contract ShareToken {
    /// @notice Total number of shares in existence.
    uint256 public totalSupply; // total share.

    /// @notice Name of the share token.
    string public name;

    /// @notice Symbol of the share token.
    string public symbol;

    /// @notice Decimals used by the share token.
    uint8 public decimals;

    /// @notice Address allowed to mint and burn shares.
    address public owner;

    /// @dev Internal mapping of share balances.
    mapping(address => uint256) private _balanceOf;

    /// @notice Approved share allowances by owner and spender.
    mapping(address => mapping(address => uint256)) public allowance;

    /**
     * @notice Emitted when shares are transferred.
     * @param sender Address sending shares.
     * @param receiver Address receiving shares.
     * @param amount Amount of shares transferred.
     */
    event Transfer(address indexed sender, address indexed receiver, uint256 amount);

    /**
     * @notice Emitted when an allowance is approved.
     * @param owner Address granting the allowance.
     * @param spender Address receiving the allowance.
     * @param value Amount of allowance approved.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @notice Thrown when a spender has insufficient allowance.
     */
    error InsufficentAllowance();

    /**
     * @notice Thrown when an account has insufficient balance.
     */
    error InsufficentBalance();

    /**
     * @notice Deploys the share token.
     * @param _name Name of the share token.
     * @param _symbol Symbol of the share token.
     * @param _decimals Decimals used by the share token.
     * @param _totalSupply Initial total supply of shares.
     */
    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _totalSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply;
        owner = msg.sender;
    }

    /**
     * @notice Mints new shares to an address.
     * @dev Only the owner can call this function.
     * @param _amount Amount of shares to mint.
     * @param _to Address receiving the minted shares.
     */
    function mint(uint256 _amount, address _to) external {
        require(owner == msg.sender, "you are not the owner of this token");
        totalSupply += _amount;
        _balanceOf[_to] += _amount;
    }

    /**
     * @notice Burns shares from an address.
     * @dev Only the owner can call this function.
     * @param _from Address whose shares will be burned.
     * @param _amount Amount of shares to burn.
     */
    function burn(address _from, uint256 _amount) external {
        require(owner == msg.sender, "not owner");
        require(_balanceOf[_from] >= _amount, "insufficient");
        _balanceOf[_from] -= _amount;
        totalSupply -= _amount;
    }

    /**
     * @notice Transfers shares to another address.
     * @param _to Address receiving the shares.
     * @param _amount Amount of shares to transfer.
     * @return success True if the transfer succeeded.
     */
    function transfer(address _to, uint256 _amount) external returns (bool) {
        if (_balanceOf[msg.sender] < _amount) revert InsufficentBalance();

        _balanceOf[msg.sender] -= _amount;
        _balanceOf[_to] += _amount;

        emit Transfer(msg.sender, _to, _amount);
        return true;
    }

    /**
     * @notice Approves a spender to spend shares.
     * @param _spender Address receiving the allowance.
     * @param _amount Amount of shares approved.
     * @return success True if the approval succeeded.
     */
    function approve(address _spender, uint256 _amount) external returns (bool) {
        allowance[msg.sender][_spender] = _amount;

        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    /**
     * @notice Transfers shares from one address to another using an allowance.
     * @param _from Address to transfer shares from.
     * @param _to Address to transfer shares to.
     * @param _amount Amount of shares to transfer.
     * @return success True if the transfer succeeded.
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

    /**
     * @notice Returns whether an owner has approved a spender.
     * @param _owner Address that granted the allowance.
     * @param _to Address that received the allowance.
     * @return True if the allowance is non-zero, false otherwise.
     */
    function checkApproval(address _owner, address _to) external view returns (bool) {
        if (allowance[_owner][_to] == 0) return false;

        return true;
    }

    /**
     * @notice Returns the total share supply.
     * @return The total number of shares.
     */
    function totalSupplies() external view returns (uint256) {
        return totalSupply;
    }

    /**
     * @notice Returns the share balance of an address.
     * @param _address Address to query.
     * @return The share balance of `_address`.
     */
    function balanceOf(address _address) external view returns (uint256) {
        return _balanceOf[_address];
    }
}

/**
 * @title Vault
 * @author Mikiyas Yimer.
 * @notice Accepts a single ERC20 token and issues proportional ownership shares.
 * @dev Deposits pull tokens with `transferFrom` and mint shares. Withdrawals burn shares
 *      and return underlying tokens. This implementation intentionally keeps the raw
 *      share math and does not include ERC4626-style inflation-attack mitigations.
 */
contract Vault {
    /// @notice The underlying ERC20 token accepted by the vault.
    IAsout3Token public token;

    /// @notice The share token minted and burned by the vault.
    ShareToken public shareToken;

    /**
     * @notice Emitted when a user deposits underlying tokens.
     * @param _address Address that deposited.
     * @param _amount Amount of underlying tokens deposited.
     */
    event Deposite(address indexed _address, uint256 indexed _amount);

    /**
     * @notice Emitted when a user withdraws underlying tokens.
     * @param _address Address that withdrew.
     * @param _amount Amount of underlying tokens withdrawn.
     */
    event Withdraw(address indexed _address, uint256 indexed _amount);

    /**
     * @notice Thrown when a zero amount is supplied.
     */
    error ZeroAmountInputed();

    /**
     * @notice Thrown when an account has insufficient shares.
     */
    error InsufficentShare();

    /**
     * @notice Creates a vault for a given underlying token.
     * @dev Deploys a new ShareToken owned by the vault.
     * @param _token Address of the underlying token.
     */
    constructor(address _token) {
        token = IAsout3Token(_token);
        shareToken = new ShareToken("Vault Share", "VSHARE", 18, 0);
    }

    /**
     * @notice Deposits underlying tokens and mints vault shares.
     * @dev Pulls `_amount` from the caller using `transferFrom`; the caller must approve
     *      the vault first. The first deposit mints shares 1:1. Later deposits use:
     *      shares = (_amount * totalShares) / totalAssets.
     * @param _amount Amount of underlying tokens to deposit.
     */
    function deposite(uint256 _amount) external {
        if (_amount == 0) revert ZeroAmountInputed();
        // this is the share variable which i used to store the share to calculate
        uint256 share;

        if (shareToken.totalSupplies() == 0) {
            share = _amount;
        } else {
            share = (_amount * shareToken.totalSupplies()) / token.balanceOf(address(this));
        }

        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, "transaction failed");

        shareToken.mint(share, msg.sender);
        emit Deposite(msg.sender, _amount);
    }

    /**
     * @notice Withdraws underlying tokens by burning vault shares.
     * @dev amount = (_sharesToBurn * totalAssets) / totalShares.
     * @param _sharesToBurn Number of shares to burn.
     */
    function withdraw(uint256 _sharesToBurn) external {
        if (shareToken.balanceOf(msg.sender) < _sharesToBurn) revert InsufficentShare();
        if (_sharesToBurn == 0) revert ZeroAmountInputed();
        // calculate tokens to give back: amount = (shares * totalAssets) / totalShares
        uint256 amount;

        amount = (_sharesToBurn * token.balanceOf(address(this))) / shareToken.totalSupplies();

        // burn shares
        shareToken.burn(msg.sender, _sharesToBurn);

        // send tokens to user
        bool success = token.transfer(msg.sender, amount);
        require(success, "transactoin failed");

        emit Withdraw(msg.sender, amount);
    }

    /**
     * @notice Previews the number of shares a deposit would mint.
     * @dev Does not modify state.
     * @param _amount Amount of underlying tokens to preview.
     * @return share Number of shares that would be minted.
     */
    function previewDeposit(uint256 _amount) external view returns (uint256) {
        uint256 share;

        if (shareToken.totalSupplies() == 0) {
            return _amount;
        } else {
            share = (_amount * shareToken.totalSupplies()) / token.balanceOf(address(this));
            return share;
        }
    }

    /**
     * @notice Returns the total underlying assets held by the vault.
     * @return The underlying token balance of the vault.
     */
    //Anyone can check the total assets held by the vault
    function totalAsset() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @notice Returns the number of shares held by an address.
     * @param _address Address to query.
     * @return The share balance of `_address`.
     */
    //Anyone can check how many shares an address holds
    function sharesOf(address _address) external view returns (uint256) {
        return shareToken.balanceOf(_address);
    }
}
