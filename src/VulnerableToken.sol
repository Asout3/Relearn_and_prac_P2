// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @title VulnerableToken.
/// @author Mikiyas.
/// @dev This is vulnerable token experiment.
contract VulnerableToken {
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    event Minted(address indexed to, uint256 amount);
    event Transferred(address indexed from, address indexed to, uint256 amount);

    error InsufficientBalance();
    error CanNotSendToZeroAddress();

    function mint(address _to, uint256 _amount) external {
        unchecked {
            balanceOf[_to] += _amount;
            totalSupply += _amount;
        }

        emit Minted(_to, _amount);
    }

    function transfer(address _to, uint256 _amount) external {
        if (address(0) == _to) revert CanNotSendToZeroAddress();

        unchecked {
            balanceOf[msg.sender] -= _amount;
            balanceOf[_to] += _amount;
        }

        emit Transferred(msg.sender, _to, _amount);
    }
}
