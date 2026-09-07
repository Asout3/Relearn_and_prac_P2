// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @custom:info This is an exercise where i fix the old existing contract(done in phase 1 of relearning solidity) to look professional.
/// @custom:info I fixed it by improving its documentation and by following solidity best practices.
/// @custom:info You can find the original contract in this link: https://github.com/Asout3/Relearn_and_prac/blob/main/src/Asout3Token.sol

/// @title Asout3Token.
/// @author Mikiyas Yimer.
/// @notice This is just simple exercise solidity code. Don't push this code to production.
/// @dev Don't push this code to production.
/// @custom:experimental This is an experimental contract.
contract Asout3Token {
    /// @notice name of the token.
    string public name;
    /// @notice symbol of toke.
    string public symbol;
    /// @notice decimal the token can have.
    uint8 public decimals;

    /// @notice the total supply of the token.
    uint256 public totalSupply;

    /// @notice mapping to track balance of the user
    mapping(address => uint256) private _balanceOf;
    /// @notice mapping to track the allowance and the amount allowed
    mapping(address => mapping(address => uint256)) public allowance;

    /// @notice two most important events.
    /// @dev event triggered by token transfer.
    event Transfer(address indexed sender, address indexed receiver, uint256 amount);
    /// @dev event triggered by approval for spending.
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice custom errors.
    /// @dev error is triggered by insufficient allowance.
    error InsufficientAllowance();
    /// @dev error is triggered by insufficient balance.
    error InsufficientBalance();

    /// @notice This constructor helps to initialize the token.
    /// @param _name the name of the token.
    /// @param _symbol the symbol of the token.
    /// @param _decimals the amount of decimal the token should have.
    /// @param _totalSupply the total supply of this token.
    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _totalSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply;
        _balanceOf[msg.sender] = _totalSupply;
    }

    /// @notice transfers token function.
    /// @param _to the receiver of the token.
    /// @param _amount the amount of token we intend to transfer.
    /// @return true if the transaction succeeded.
    function transfer(address _to, uint256 _amount) external returns (bool) {
        if (balanceOf(msg.sender) < _amount) revert InsufficientBalance();

        _balanceOf[msg.sender] -= _amount;
        _balanceOf[_to] += _amount;

        emit Transfer(msg.sender, _to, _amount);
        return true;
    }

    /// @notice approval function.
    /// @param _spender the address of the spender.
    /// @param _amount the amount of token we allow the spender to spend.
    /// @return true if transaction pass.
    function approve(address _spender, uint256 _amount) external returns (bool) {
        allowance[msg.sender][_spender] = _amount;

        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    /// @notice transfer from function.
    /// @param _from the address where we get the token from.
    /// @param _to the address where to transfer to.
    /// @param _amount the amount of token we want to transfer.
    /// @return true if transaction pass.
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool) {
        if (allowance[_from][msg.sender] < _amount) revert InsufficientAllowance();
        if (balanceOf(_from) < _amount) revert InsufficientBalance();

        allowance[_from][msg.sender] -= _amount;
        _balanceOf[_from] -= _amount;
        _balanceOf[_to] += _amount;

        emit Transfer(_from, _to, _amount);
        return true;
    }

    /// @notice check approval function.
    /// @param _owner owner of that address which gives you approval.
    /// @param _to is the address spender.
    /// @return true if transaction pass.
    function checkApproval(address _owner, address _to) external view returns (bool) {
        if (allowance[_owner][_to] == 0) return false;

        return true;
    }

    /// @notice check the total supply.
    /// @return the amount of total supply.
    function totalSupplies() external view returns (uint256) {
        return totalSupply;
    }

    /// @notice check the balance of an address.
    /// @param _address the address which we check the balance.
    /// @return the amount of token we have.
    function balanceOf(address _address) public view returns (uint256) {
        return _balanceOf[_address];
    }
}

