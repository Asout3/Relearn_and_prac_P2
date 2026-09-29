// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title A simulator for Vulnerable Bank.
/// @author Mikiyas.
/// @notice This is vulnerable bank which is affected by reentrancy bug.
contract VulnerableBank {
    mapping(address => uint256) public balanceOf;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    error InsufficientBalance();
    error TransferFailed();

    receive() external payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 _amount) external {
        if (balanceOf[msg.sender] < _amount) revert InsufficientBalance();

        (bool ok,) = payable(msg.sender).call{value: _amount}("");
        if (!ok) revert TransferFailed();

        /// @dev To make the attack it got to be unchecked other wise it will revert.
        unchecked {
            balanceOf[msg.sender] -= _amount;
        }
        emit Withdrawn(msg.sender, _amount);
    }

    function checkBalance() external view returns (uint256 totalBalance) {
        totalBalance = address(this).balance;
    }
}
