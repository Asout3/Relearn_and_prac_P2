// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @title A simulator for safe Bank.
/// @author Mikiyas.
/// @notice This is safe bank which is fixed version of VulnerableBank.sol
contract SafeBank {
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

        /// @dev This is for gas optimization. when it underflow it will get
        ///      caught on the custom error at the end of this function.
        unchecked {
            balanceOf[msg.sender] -= _amount;
        }

        (bool ok,) = payable(msg.sender).call{value: _amount}("");
        if (!ok) revert TransferFailed();

        emit Withdrawn(msg.sender, _amount);
    }

    function checkBalance() external view returns (uint256 totalBalance) {
        totalBalance = address(this).balance;
    }
}
