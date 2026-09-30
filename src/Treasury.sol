// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title Treasury
/// @author Mikiyas y.
/// @notice A treasury that accepts deposits and allows role-gated withdrawals.
/// @dev Demonstrates OpenZeppelin AccessControl with custom roles.
contract Treasury is AccessControl {
    /// @notice Role allowed to withdraw funds from the treasury.
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice Role allowed to view the treasury balance.
    bytes32 public constant VIEWER_ROLE = keccak256("VIEWER_ROLE");

    /// @notice Emitted when ETH is deposited into the treasury.
    /// @param sender The address that sent the ETH.
    /// @param amount The amount deposited, in wei.
    event Deposited(address indexed sender, uint256 amount);

    /// @notice Emitted when ETH is withdrawn from the treasury.
    /// @param account The address receiving the ETH.
    /// @param amount The amount withdrawn, in wei.
    event Withdrawn(address indexed account, uint256 amount);

    /// @notice Thrown when the requested amount exceeds the treasury balance.
    error InsufficientBalance();
    /// @notice Thrown when the ETH transfer to the recipient fails.
    error TransferFailed();
    /// @notice Thrown when the initial admin is the zero address.
    error InvalidAdmin();

    /// @param admin Address granted {DEFAULT_ADMIN_ROLE}.
    constructor(address admin) {
        if (admin == address(0)) revert InvalidAdmin();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Accept plain ETH transfers.
    receive() external payable {
        deposit();
    }

    /// @notice Withdraw ETH from the treasury to the caller.
    /// @dev Only callable by accounts with {DEFAULT_ADMIN_ROLE}.
    /// @param amount The amount to withdraw, in wei.
    function withdraw(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _withdraw(amount);
    }

    /// @notice Withdraw ETH from the treasury to the caller.
    /// @dev Only callable by accounts with {MANAGER_ROLE}.
    /// @param amount The amount to withdraw, in wei.
    function managerWithdraw(uint256 amount) external onlyRole(MANAGER_ROLE) {
        _withdraw(amount);
    }

    /// @notice Returns the total ETH held by the treasury.
    /// @dev Only callable by accounts with {VIEWER_ROLE}.
    /// @return The treasury balance in wei.
    function viewBalance() external view onlyRole(VIEWER_ROLE) returns (uint256) {
        return address(this).balance;
    }

    /// @notice Deposit ETH into the treasury.
    /// @dev Also triggered by plain ETH transfers via {receive}.
    function deposit() public payable {
        emit Deposited(msg.sender, msg.value);
    }

    /// @dev Shared withdrawal logic. Follows CEI order.
    function _withdraw(uint256 amount) private {
        if (address(this).balance < amount) revert InsufficientBalance();

        emit Withdrawn(msg.sender, amount);

        (bool ok,) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
